"""Pydantic schemas for request/response validation."""
from datetime import datetime, date
from uuid import UUID
from typing import Optional, Any
from pydantic import BaseModel, EmailStr


# ── Auth ──────────────────────────────────────────────────────────────────

class UserCreate(BaseModel):
    email: EmailStr
    password: str
    display_name: Optional[str] = None
    interface_lang: str = "ru"
    target_lang: str = "en"


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
    avatar_url: Optional[str] = None
    auth_provider: str
    interface_lang: str
    target_lang: str
    current_phase_id: Optional[int] = None
    xp: int
    current_streak: int
    created_at: datetime
    # Convenience fields populated by the profile endpoint
    # (sourced from the new `game_scores` table).
    game_scores: dict[str, int] = {}

    class Config:
        from_attributes = True


class UserUpdate(BaseModel):
    display_name: Optional[str] = None
    interface_lang: Optional[str] = None
    target_lang: Optional[str] = None
    avatar_url: Optional[str] = None


# ── Content ───────────────────────────────────────────────────────────────

class PhaseResponse(BaseModel):
    id: int
    title_translations: dict[str, str]
    internal_cefr_level: str
    required_lessons_to_pass: int

    class Config:
        from_attributes = True


class CategoryResponse(BaseModel):
    id: int
    phase_id: int
    name_translations: dict[str, str]
    icon_name: str
    completed_lessons: int = 0
    total_lessons: int = 0

    class Config:
        from_attributes = True


class LessonResponse(BaseModel):
    id: int
    category_id: int
    topic_translations: dict[str, str]
    order_index: int
    is_completed: bool = False

    class Config:
        from_attributes = True


class SRSItemResponse(BaseModel):
    """Item due for review, with the user's SRS metadata attached."""
    item_id: int
    text_content: str
    translations: dict[str, str]
    item_type: str
    correct_streak: int
    ease_factor: float
    interval_days: int
    next_review_date: Optional[date] = None


class SRSReviewRequest(BaseModel):
    item_id: int
    quality: int  # 0..5 grade per SM-2 (0=fail, 5=perfect)


class ItemResponse(BaseModel):
    id: int
    lesson_id: int
    item_type: str
    text_content: str
    translations: dict[str, str]
    extra_data_json: Optional[Any] = None

    class Config:
        from_attributes = True


# ── Progress ──────────────────────────────────────────────────────────────

class CompleteLessonRequest(BaseModel):
    lesson_id: int


class PhaseStatusResponse(BaseModel):
    phase_id: int
    total_lessons: int
    completed_lessons: int
    can_take_exam: bool

class GameFinishRequest(BaseModel):
    game_type: str  # 'match' or 'sprint'
    score: int

class GameFinishResponse(BaseModel):
    xp_earned: int
    new_highscore: int
    is_new_record: bool
    total_xp: int


# ── Exam ──────────────────────────────────────────────────────────────────

class ExamAnswer(BaseModel):
    item_id: int
    user_answer: str


class ExamSubmitRequest(BaseModel):
    answers: list[ExamAnswer]


class ExamResultResponse(BaseModel):
    score: float
    passed: bool
    total_questions: int
    correct_answers: int
    new_phase_id: Optional[int] = None


# ── Placement ─────────────────────────────────────────────────────────────

class PlacementQuestion(BaseModel):
    id: int
    question: str
    options: list[str]
    difficulty: str


class PlacementAnswer(BaseModel):
    question_id: int
    answer: str


class PlacementSubmitRequest(BaseModel):
    answers: list[PlacementAnswer]


class PlacementResultResponse(BaseModel):
    assigned_phase_id: int
    cefr_level: str
    message: str


# ── Speaking ──────────────────────────────────────────────────────────────

class SpeakingVerifyResponse(BaseModel):
    transcription: str
    target_text: str
    accuracy: float
    is_correct: bool


# ── Qalqan Family Protection ──────────────────────────────────────────────

class QalqanProfileUpsert(BaseModel):
    subscription_plan: str = "personal"
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
