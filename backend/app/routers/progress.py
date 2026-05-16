"""Progress router – lesson completion, phase status, games, SRS reviews."""
from datetime import date, datetime
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models import (
    User, Lesson, Category, Item, UserCompletedLesson,
    UserLearnedItem, GameScore,
)
from app.schemas import (
    CompleteLessonRequest, PhaseStatusResponse, GameFinishRequest,
    SRSItemResponse, SRSReviewRequest,
)
from app.auth import get_current_user

router = APIRouter(prefix="/progress", tags=["progress"])

XP_PER_LESSON = 25
SRS_DUE_LIMIT = 30  # max items returned in a single review batch

GAME_XP_DIVISOR = {"match": 15, "sprint": 50}


def _bump_streak(user: User) -> None:
    """Update daily streak based on last activity date (idempotent per day)."""
    today = date.today()
    last = user.last_activity_date
    if last == today:
        return
    if last is None or (today - last).days > 1:
        user.current_streak = 1
    elif (today - last).days == 1:
        user.current_streak = (user.current_streak or 0) + 1
    user.last_activity_date = today


@router.post("/complete-lesson")
async def complete_lesson(
    data: CompleteLessonRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    existing = await db.execute(
        select(UserCompletedLesson).where(
            UserCompletedLesson.user_id == user.id,
            UserCompletedLesson.lesson_id == data.lesson_id,
        )
    )
    if existing.scalar_one_or_none():
        return {"message": "Already completed", "xp_earned": 0, "total_xp": user.xp}

    db.add(UserCompletedLesson(user_id=user.id, lesson_id=data.lesson_id))
    user.xp = (user.xp or 0) + XP_PER_LESSON
    _bump_streak(user)
    db.add(user)
    # No explicit commit — get_db handles it on success.
    return {
        "message": "Lesson completed",
        "xp_earned": XP_PER_LESSON,
        "total_xp": user.xp,
    }


@router.get("/phase-status", response_model=PhaseStatusResponse)
async def phase_status(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    phase_id = user.current_phase_id or 1

    total_q = await db.execute(
        select(func.count())
        .select_from(Lesson)
        .join(Category, Category.id == Lesson.category_id)
        .where(Category.phase_id == phase_id)
    )
    total = total_q.scalar() or 0

    completed_q = await db.execute(
        select(func.count())
        .select_from(UserCompletedLesson)
        .join(Lesson, Lesson.id == UserCompletedLesson.lesson_id)
        .join(Category, Category.id == Lesson.category_id)
        .where(
            UserCompletedLesson.user_id == user.id,
            Category.phase_id == phase_id,
        )
    )
    completed = completed_q.scalar() or 0

    return PhaseStatusResponse(
        phase_id=phase_id,
        total_lessons=total,
        completed_lessons=completed,
        can_take_exam=completed >= total and total > 0,
    )


@router.post("/games/finish", response_model=dict)
async def finish_game(
    data: GameFinishRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    divisor = GAME_XP_DIVISOR.get(data.game_type, 50)
    xp_earned = max(0, data.score // divisor)
    user.xp = (user.xp or 0) + xp_earned

    # Upsert game score row.
    res = await db.execute(
        select(GameScore).where(
            GameScore.user_id == user.id,
            GameScore.game_type == data.game_type,
        )
    )
    score_row = res.scalar_one_or_none()
    is_new_record = False
    if score_row is None:
        score_row = GameScore(
            user_id=user.id,
            game_type=data.game_type,
            highscore=data.score,
            plays_count=1,
            last_played_at=datetime.utcnow(),
        )
        db.add(score_row)
        is_new_record = data.score > 0
    else:
        score_row.plays_count = (score_row.plays_count or 0) + 1
        score_row.last_played_at = datetime.utcnow()
        if data.score > (score_row.highscore or 0):
            score_row.highscore = data.score
            is_new_record = True

    _bump_streak(user)
    db.add(user)

    return {
        "xp_earned": xp_earned,
        "new_highscore": score_row.highscore,
        "is_new_record": is_new_record,
        "total_xp": user.xp,
    }


# ── Spaced repetition (SM-2 lite) ──────────────────────────────────────

@router.get("/srs/due", response_model=list[SRSItemResponse])
async def srs_due(
    limit: int = SRS_DUE_LIMIT,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Items the user should review today (next_review_date ≤ today)."""
    today = date.today()
    stmt = (
        select(UserLearnedItem, Item)
        .join(Item, Item.id == UserLearnedItem.item_id)
        .where(
            UserLearnedItem.user_id == user.id,
            (UserLearnedItem.next_review_date.is_(None))
            | (UserLearnedItem.next_review_date <= today),
        )
        .order_by(UserLearnedItem.next_review_date.asc().nullsfirst())
        .limit(min(max(limit, 1), 100))
    )
    rows = (await db.execute(stmt)).all()
    return [
        SRSItemResponse(
            item_id=item.id,
            text_content=item.text_content,
            translations=item.translations,
            item_type=item.item_type,
            correct_streak=rec.correct_streak,
            ease_factor=rec.ease_factor,
            interval_days=rec.interval_days,
            next_review_date=rec.next_review_date,
        )
        for rec, item in rows
    ]


def _sm2_update(
    rec: UserLearnedItem, quality: int
) -> tuple[int, float, int]:
    """Apply SM-2 update rules. quality ∈ [0, 5].
    Returns (new_correct_streak, new_ease_factor, new_interval_days).
    """
    quality = max(0, min(5, quality))
    if quality < 3:
        new_streak = 0
        new_interval = 1
    else:
        new_streak = (rec.correct_streak or 0) + 1
        if new_streak == 1:
            new_interval = 1
        elif new_streak == 2:
            new_interval = 6
        else:
            new_interval = max(1, round((rec.interval_days or 1) * (rec.ease_factor or 2.5)))
    new_ef = (rec.ease_factor or 2.5) + (
        0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02)
    )
    new_ef = max(1.3, new_ef)
    return new_streak, new_ef, new_interval


@router.post("/srs/review")
async def srs_review(
    data: SRSReviewRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Record a single review using SM-2 (SuperMemo) update rules."""
    res = await db.execute(
        select(UserLearnedItem).where(
            UserLearnedItem.user_id == user.id,
            UserLearnedItem.item_id == data.item_id,
        )
    )
    rec = res.scalar_one_or_none()
    if rec is None:
        # Verify item exists before creating an SRS row for it.
        item_exists = (
            await db.execute(select(Item.id).where(Item.id == data.item_id))
        ).scalar_one_or_none()
        if item_exists is None:
            raise HTTPException(status_code=404, detail="Item not found")
        rec = UserLearnedItem(
            user_id=user.id,
            item_id=data.item_id,
            mistakes_count=0,
            correct_streak=0,
            ease_factor=2.5,
            interval_days=0,
        )
        db.add(rec)

    new_streak, new_ef, new_interval = _sm2_update(rec, data.quality)
    if data.quality < 3:
        rec.mistakes_count = (rec.mistakes_count or 0) + 1
    rec.correct_streak = new_streak
    rec.ease_factor = round(new_ef, 3)
    rec.interval_days = new_interval
    rec.last_reviewed_date = date.today()
    rec.next_review_date = date.fromordinal(
        date.today().toordinal() + new_interval
    )

    return {
        "item_id": data.item_id,
        "correct_streak": rec.correct_streak,
        "ease_factor": rec.ease_factor,
        "interval_days": rec.interval_days,
        "next_review_date": rec.next_review_date.isoformat(),
    }
