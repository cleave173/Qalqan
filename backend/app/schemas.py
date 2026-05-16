"""Pydantic schemas for Qalqan API requests and responses."""
from datetime import datetime
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, EmailStr


class UserCreate(BaseModel):
    email: EmailStr
    password: str
    display_name: Optional[str] = None


class UserLogin(BaseModel):
    email: EmailStr
    password: str


class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"


class UserResponse(BaseModel):
    id: UUID
    email: str
    display_name: Optional[str] = None
    created_at: datetime

    class Config:
        from_attributes = True


class QalqanProfileUpsert(BaseModel):
    subscription_plan: str = "personal"
    subscription_period: str = "monthly"
    child_phone: Optional[str] = None
    telegram_chat_id: Optional[str] = None


class QalqanParentBindRequest(BaseModel):
    phone: str
    display_name: Optional[str] = None


class QalqanParentResponse(BaseModel):
    id: int
    phone: str
    display_name: Optional[str] = None
    created_at: datetime

    class Config:
        from_attributes = True


class QalqanProfileResponse(BaseModel):
    subscription_plan: str
    subscription_period: str
    subscription_status: str
    subscription_expires_at: Optional[datetime] = None
    parent_limit: int
    child_phone: Optional[str] = None
    telegram_chat_id: Optional[str] = None
    parents: list[QalqanParentResponse] = []


class QalqanAlertRequest(BaseModel):
    alert_type: str
    parent_phone: Optional[str] = None
    sender: Optional[str] = None
    code: Optional[str] = None
    trigger_phrase: Optional[str] = None
    transcription: Optional[str] = None


class QalqanAlertResponse(BaseModel):
    ok: bool
    telegram_sent: bool
    message: str
