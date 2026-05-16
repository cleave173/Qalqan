"""Content router – phases, categories, lessons, items."""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select, func, case
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models import Phase, Category, Lesson, Item, User, UserCompletedLesson
from app.schemas import (
    PhaseResponse, CategoryResponse, LessonResponse, ItemResponse,
)
from app.auth import get_current_user

router = APIRouter(prefix="/content", tags=["content"])


@router.get("/phases", response_model=list[PhaseResponse])
async def list_phases(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Phase).order_by(Phase.id))
    return result.scalars().all()


@router.get("/phases/{phase_id}/categories", response_model=list[CategoryResponse])
async def list_categories(
    phase_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Single GROUP BY query — replaces the previous N+1 (1 + 2N) pattern."""
    completed_expr = func.count(
        case((UserCompletedLesson.id.isnot(None), 1))
    )
    total_expr = func.count(Lesson.id)

    stmt = (
        select(
            Category.id,
            Category.phase_id,
            Category.name_translations,
            Category.icon_name,
            total_expr.label("total"),
            completed_expr.label("completed"),
        )
        .join(Lesson, Lesson.category_id == Category.id, isouter=True)
        .join(
            UserCompletedLesson,
            (UserCompletedLesson.lesson_id == Lesson.id)
            & (UserCompletedLesson.user_id == user.id),
            isouter=True,
        )
        .where(Category.phase_id == phase_id)
        .group_by(Category.id)
        .order_by(Category.id)
    )

    rows = (await db.execute(stmt)).all()
    if not rows:
        raise HTTPException(status_code=404, detail="Phase not found")

    return [
        CategoryResponse(
            id=row.id,
            phase_id=row.phase_id,
            name_translations=row.name_translations,
            icon_name=row.icon_name,
            completed_lessons=int(row.completed or 0),
            total_lessons=int(row.total or 0),
        )
        for row in rows
    ]


@router.get("/categories/{category_id}/lessons", response_model=list[LessonResponse])
async def list_lessons(
    category_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    completed_expr = case(
        (UserCompletedLesson.id.isnot(None), True), else_=False
    ).label("is_completed")

    stmt = (
        select(Lesson, completed_expr)
        .join(
            UserCompletedLesson,
            (UserCompletedLesson.lesson_id == Lesson.id)
            & (UserCompletedLesson.user_id == user.id),
            isouter=True,
        )
        .where(Lesson.category_id == category_id)
        .order_by(Lesson.order_index)
    )
    rows = (await db.execute(stmt)).all()

    return [
        LessonResponse(
            id=lesson.id,
            category_id=lesson.category_id,
            topic_translations=lesson.topic_translations,
            order_index=lesson.order_index,
            is_completed=bool(is_completed),
        )
        for lesson, is_completed in rows
    ]


@router.get("/lessons/{lesson_id}/items", response_model=list[ItemResponse])
async def list_items(
    lesson_id: int,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(Item).where(Item.lesson_id == lesson_id).order_by(Item.id)
    )
    items = result.scalars().all()
    if not items:
        raise HTTPException(status_code=404, detail="Lesson not found or empty")
    return items


@router.get("/phases/{phase_id}/games/words", response_model=list[ItemResponse])
async def get_game_words(
    phase_id: int,
    limit: int = 20,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Fetch random word items from the current phase for mini-games."""
    # Find all lessons in this phase
    lesson_ids_q = await db.execute(
        select(Lesson.id)
        .join(Category, Category.id == Lesson.category_id)
        .where(Category.phase_id == phase_id)
    )
    lesson_ids = [row[0] for row in lesson_ids_q.all()]

    if not lesson_ids:
        raise HTTPException(status_code=404, detail="No lessons found in this phase")

    # Fetch random words
    result = await db.execute(
        select(Item)
        .where(Item.lesson_id.in_(lesson_ids))
        .where(Item.item_type == 'word')
        # PostgreSQL random order
        .order_by(func.random())
        .limit(limit)
    )
    items = result.scalars().all()
    if not items:
        raise HTTPException(status_code=404, detail="No words found for games")

    return items
