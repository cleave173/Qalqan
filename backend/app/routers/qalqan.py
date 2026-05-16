"""Qalqan family protection MVP router."""
import os
import re
from datetime import datetime, timedelta

import httpx
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import get_current_user
from app.database import get_db
from app.models import QalqanAlertLog, QalqanParentPhone, QalqanProfile, User
from app.schemas import (
    QalqanAlertRequest,
    QalqanAlertResponse,
    QalqanParentBindRequest,
    QalqanParentResponse,
    QalqanProfileResponse,
    QalqanProfileUpsert,
    QalqanSubscriptionCheckoutRequest,
)

router = APIRouter(prefix="/qalqan", tags=["qalqan"])

PLAN_LIMITS = {
    "personal": 1,
    "family": 4,
}

PERIOD_DAYS = {
    "monthly": 30,
    "yearly": 365,
}

TRIAL_DAYS = 20


def _normalize_plan(plan: str) -> str:
    normalized = plan.strip().lower()
    if normalized not in PLAN_LIMITS:
        raise HTTPException(status_code=400, detail="Unknown Qalqan tariff")
    return normalized


def _normalize_period(period: str) -> str:
    normalized = period.strip().lower()
    if normalized not in PERIOD_DAYS:
        raise HTTPException(status_code=400, detail="Unknown Qalqan billing period")
    return normalized


def _normalize_phone(phone: str) -> str:
    cleaned = re.sub(r"[^\d+]", "", phone)
    if not re.fullmatch(r"\+?\d{10,15}", cleaned):
        raise HTTPException(status_code=400, detail="Invalid phone number")
    return cleaned


async def _ensure_profile(user: User, db: AsyncSession) -> QalqanProfile:
    profile = await db.get(QalqanProfile, user.id)
    if profile is None:
        profile = QalqanProfile(
            user_id=user.id,
            subscription_plan="personal",
            subscription_period="monthly",
            subscription_status="trial",
            subscription_expires_at=_trial_expiry(),
        )
        db.add(profile)
        await db.flush()
    return profile


def _trial_expiry() -> datetime:
    return datetime.utcnow() + timedelta(days=TRIAL_DAYS)


def _subscription_expiry(period: str) -> datetime:
    return datetime.utcnow() + timedelta(days=PERIOD_DAYS[period])


def _trial_days_remaining(profile: QalqanProfile) -> int:
    if profile.subscription_status != "trial" or profile.subscription_expires_at is None:
        return 0
    remaining = profile.subscription_expires_at - datetime.utcnow()
    return max(0, remaining.days + (1 if remaining.seconds else 0))


async def _refresh_subscription_status(
    profile: QalqanProfile,
    db: AsyncSession,
) -> None:
    if (
        profile.subscription_status in {"trial", "active"}
        and profile.subscription_expires_at is not None
        and profile.subscription_expires_at <= datetime.utcnow()
    ):
        profile.subscription_status = "expired"
        db.add(profile)
        await db.flush()


async def _require_available_subscription(
    profile: QalqanProfile,
    db: AsyncSession,
) -> None:
    await _refresh_subscription_status(profile, db)
    if profile.subscription_status == "expired":
        raise HTTPException(
            status_code=402,
            detail="Subscription expired. Complete demo checkout to continue.",
        )


async def _parent_count(user: User, db: AsyncSession) -> int:
    count_result = await db.execute(
        select(func.count(QalqanParentPhone.id)).where(
            QalqanParentPhone.child_user_id == user.id
        )
    )
    return count_result.scalar_one()


async def _profile_response(user: User, db: AsyncSession) -> QalqanProfileResponse:
    profile = await _ensure_profile(user, db)
    await _refresh_subscription_status(profile, db)
    parents_result = await db.execute(
        select(QalqanParentPhone)
        .where(QalqanParentPhone.child_user_id == user.id)
        .order_by(QalqanParentPhone.created_at.asc())
    )
    parents = list(parents_result.scalars().all())
    limit = PLAN_LIMITS.get(profile.subscription_plan, 1)
    return QalqanProfileResponse(
        subscription_plan=profile.subscription_plan,
        subscription_period=profile.subscription_period,
        subscription_status=profile.subscription_status,
        subscription_expires_at=profile.subscription_expires_at,
        trial_days_remaining=_trial_days_remaining(profile),
        parent_limit=limit,
        child_phone=profile.child_phone,
        telegram_chat_id=profile.telegram_chat_id,
        parents=[QalqanParentResponse.model_validate(parent) for parent in parents],
    )


@router.get("/profile", response_model=QalqanProfileResponse)
async def get_profile(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await _profile_response(user, db)


@router.put("/profile", response_model=QalqanProfileResponse)
async def upsert_profile(
    data: QalqanProfileUpsert,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    profile = await _ensure_profile(user, db)
    profile.child_phone = _normalize_phone(data.child_phone) if data.child_phone else None
    profile.telegram_chat_id = data.telegram_chat_id.strip() if data.telegram_chat_id else None
    db.add(profile)
    await db.flush()
    return await _profile_response(user, db)


@router.post("/subscription/checkout", response_model=QalqanProfileResponse)
async def checkout_subscription(
    data: QalqanSubscriptionCheckoutRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    profile = await _ensure_profile(user, db)
    next_plan = _normalize_plan(data.subscription_plan)
    next_period = _normalize_period(data.subscription_period)
    limit = PLAN_LIMITS[next_plan]
    current_count = await _parent_count(user, db)
    if current_count > limit:
        raise HTTPException(
            status_code=409,
            detail=(
                f"Current parent count ({current_count}) exceeds "
                f"{next_plan} tariff limit ({limit})"
            ),
        )

    profile.subscription_plan = next_plan
    profile.subscription_period = next_period
    profile.subscription_status = "active"
    profile.subscription_expires_at = _subscription_expiry(next_period)
    db.add(profile)
    await db.flush()
    return await _profile_response(user, db)


@router.post(
    "/parents",
    response_model=QalqanProfileResponse,
    status_code=status.HTTP_201_CREATED,
)
async def bind_parent(
    data: QalqanParentBindRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    profile = await _ensure_profile(user, db)
    await _require_available_subscription(profile, db)
    limit = PLAN_LIMITS.get(profile.subscription_plan, 1)
    phone = _normalize_phone(data.phone)

    existing = await db.execute(
        select(QalqanParentPhone).where(
            QalqanParentPhone.child_user_id == user.id,
            QalqanParentPhone.phone == phone,
        )
    )
    if existing.scalar_one_or_none():
        return await _profile_response(user, db)

    current_count = await _parent_count(user, db)
    if current_count >= limit:
        raise HTTPException(
            status_code=409,
            detail=f"Parent binding limit reached for {profile.subscription_plan} tariff",
        )

    db.add(
        QalqanParentPhone(
            child_user_id=user.id,
            phone=phone,
            display_name=data.display_name,
        )
    )
    await db.flush()
    return await _profile_response(user, db)


@router.delete("/parents/{parent_id}", response_model=QalqanProfileResponse)
async def delete_parent(
    parent_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    parent = await db.get(QalqanParentPhone, parent_id)
    if parent is None or parent.child_user_id != user.id:
        raise HTTPException(status_code=404, detail="Parent phone not found")
    await db.delete(parent)
    await db.flush()
    return await _profile_response(user, db)


@router.post("/alerts", response_model=QalqanAlertResponse)
async def send_alert(
    data: QalqanAlertRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    profile = await _ensure_profile(user, db)
    await _require_available_subscription(profile, db)
    message = _build_alert_message(data, profile)
    telegram_sent = await _send_telegram(profile.telegram_chat_id, message, data.parent_phone)

    db.add(
        QalqanAlertLog(
            child_user_id=user.id,
            parent_phone=data.parent_phone,
            alert_type=data.alert_type,
            sender=data.sender,
            code=data.code,
            trigger_phrase=data.trigger_phrase,
            message=message,
            telegram_sent=1 if telegram_sent else 0,
        )
    )
    await db.flush()

    return QalqanAlertResponse(ok=True, telegram_sent=telegram_sent, message=message)


def _build_alert_message(data: QalqanAlertRequest, profile: QalqanProfile) -> str:
    if data.alert_type == "sms_code":
        sender = data.sender or "банка/1414"
        return (
            "🚨🚨🚨 КРИТИЧЕСКАЯ ТРЕВОГА!\n"
            f"Мама говорит по телефону и ей пришел код подтверждения от {sender}! "
            "Код пытаются украсть прямо сейчас!"
        )
    phrase = data.trigger_phrase or "подозрительная фраза"
    return (
        "🚨 ТРЕВОГА АНТИФРОД!\n"
        f"Во время звонка обнаружен триггер: {phrase}.\n"
        "Срочно перезвони маме и проверь ситуацию."
    )


async def _send_telegram(
    chat_id: str | None,
    message: str,
    parent_phone: str | None,
) -> bool:
    token = os.getenv("TELEGRAM_BOT_TOKEN")
    if not token or not chat_id:
        return False

    keyboard = None
    if parent_phone:
        keyboard = {
            "inline_keyboard": [[
                {
                    "text": "📞 Срочно позвонить маме",
                    "url": f"tel:{parent_phone}",
                }
            ]]
        }

    payload = {
        "chat_id": chat_id,
        "text": message,
    }
    if keyboard:
        payload["reply_markup"] = keyboard

    try:
        async with httpx.AsyncClient(timeout=5) as client:
            response = await client.post(
                f"https://api.telegram.org/bot{token}/sendMessage",
                json=payload,
            )
        return response.status_code < 400
    except httpx.HTTPError:
        return False
