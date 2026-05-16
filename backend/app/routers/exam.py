"""Exam router – phase final exam submission."""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models import User, Phase, Category, Lesson, Item
from app.schemas import ExamSubmitRequest, ExamResultResponse, ItemResponse
from app.auth import get_current_user

router = APIRouter(prefix="/exam", tags=["exam"])

PASSING_SCORE = 0.80


@router.get("/questions", response_model=list[ItemResponse])
async def get_exam_questions(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Get 20 random 'word' items from the user's current phase for the final exam."""
    phase_id = user.current_phase_id or 1

    # Only pick 'word' type items and use SQL-level random for better performance/shuffling
    result = await db.execute(
        select(Item)
        .join(Lesson)
        .join(Category)
        .where(
            Category.phase_id == phase_id,
            Item.item_type == "word"
        )
        .order_by(func.random())
        .limit(20)
    )
    exam_items = result.scalars().all()
    
    if not exam_items:
        raise HTTPException(status_code=404, detail="No words found for this phase")

    return exam_items


@router.post("/submit", response_model=ExamResultResponse)
async def submit_exam(
    data: ExamSubmitRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Submit exam answers. If score >= 80%, unlock next phase."""
    correct = 0
    total = len(data.answers)

    for answer in data.answers:
        result = await db.execute(select(Item).where(Item.id == answer.item_id))
        item = result.scalar_one_or_none()
        if not item:
            continue

        user_ans = answer.user_answer.strip().lower()
        
        # Check if user answer matches any of the translations in the JSON dict
        # item.translations is like {"ru": "мама", "kk": "ана"}
        valid_translations = [str(v).strip().lower() for v in item.translations.values()]
        
        # Also allow matching the English word itself if the user typed it (optional but helpful)
        if user_ans in valid_translations or user_ans == item.text_content.strip().lower():
            correct += 1

    score = correct / total if total > 0 else 0
    passed = score >= PASSING_SCORE

    new_phase_id = None
    if passed:
        current_phase_id = user.current_phase_id or 1
        # Check if next phase exists
        next_phase = await db.execute(
            select(Phase).where(Phase.id == current_phase_id + 1)
        )
        next_p = next_phase.scalar_one_or_none()
        if next_p:
            user.current_phase_id = next_p.id
            new_phase_id = next_p.id
            user.xp = (user.xp or 0) + 100  # Bonus XP for passing exam
            db.add(user)

    return ExamResultResponse(
        score=round(score * 100, 1),
        passed=passed,
        total_questions=total,
        correct_answers=correct,
        new_phase_id=new_phase_id,
    )
