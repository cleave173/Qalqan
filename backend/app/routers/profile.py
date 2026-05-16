"""Profile router – view and update current user."""
from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models import User, GameScore
from app.schemas import UserResponse, UserUpdate
from app.auth import get_current_user

router = APIRouter(prefix="/profile", tags=["profile"])


async def _build_user_response(user: User, db: AsyncSession) -> UserResponse:
    rows = await db.execute(
        select(GameScore.game_type, GameScore.highscore).where(
            GameScore.user_id == user.id
        )
    )
    scores = {gt: hs for gt, hs in rows.all()}
    return UserResponse(
        id=user.id,
        email=user.email,
        display_name=user.display_name,
        avatar_url=user.avatar_url,
        auth_provider=user.auth_provider,
        interface_lang=user.interface_lang,
        target_lang=user.target_lang,
        current_phase_id=user.current_phase_id,
        xp=user.xp,
        current_streak=user.current_streak,
        created_at=user.created_at,
        game_scores=scores,
    )


@router.get("/me", response_model=UserResponse)
async def get_me(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await _build_user_response(user, db)


@router.put("/me", response_model=UserResponse)
async def update_me(
    data: UserUpdate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if data.display_name is not None:
        user.display_name = data.display_name
    if data.interface_lang is not None:
        user.interface_lang = data.interface_lang
    if data.target_lang is not None:
        user.target_lang = data.target_lang
    if data.avatar_url is not None:
        user.avatar_url = data.avatar_url
    db.add(user)
    # Commit is handled by the get_db dependency.
    await db.flush()
    await db.refresh(user)
    return await _build_user_response(user, db)
