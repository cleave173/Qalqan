"""SQLAlchemy ORM models for the language learning app.

Schema highlights (post-refactor):
 - All foreign keys are indexed (huge wins on JOIN-heavy queries).
 - Lesson topics are multilingual (`topic_translations` JSON) instead of
   a single `topic_name` string.
 - Per-user game high-scores live in their own `game_scores` table
   (instead of denormalised columns on `users`) so adding new game types
   no longer requires a migration of `users`.
 - `user_learned_items` has a real spaced-repetition payload
   (`ease_factor`, `interval_days`, `correct_streak`, `last_reviewed_date`)
   plus a unique `(user_id, item_id)` constraint so the same item can
   only have one SRS record per user.
"""
import uuid
from datetime import datetime, date
from sqlalchemy import (
    String, Integer, Float, Text, DateTime, Date,
    ForeignKey, UniqueConstraint, Index, JSON,
)
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base


# ---------------------------------------------------------------------------
# User Management
# ---------------------------------------------------------------------------

class User(Base):
    __tablename__ = "users"

    id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    email: Mapped[str] = mapped_column(
        String(255), unique=True, index=True, nullable=False
    )
    hashed_password: Mapped[str | None] = mapped_column(String(255), nullable=True)
    auth_provider: Mapped[str] = mapped_column(String(50), default="email")
    display_name: Mapped[str | None] = mapped_column(String(100), nullable=True)
    avatar_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    interface_lang: Mapped[str] = mapped_column(String(10), default="ru")
    target_lang: Mapped[str] = mapped_column(String(10), default="en")
    current_phase_id: Mapped[int | None] = mapped_column(
        Integer, ForeignKey("phases.id"), index=True, nullable=True
    )
    xp: Mapped[int] = mapped_column(Integer, default=0)
    current_streak: Mapped[int] = mapped_column(Integer, default=0)
    last_activity_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow
    )

    # Relationships
    current_phase = relationship("Phase", foreign_keys=[current_phase_id])
    completed_lessons = relationship(
        "UserCompletedLesson", back_populates="user", cascade="all, delete-orphan"
    )
    learned_items = relationship(
        "UserLearnedItem", back_populates="user", cascade="all, delete-orphan"
    )
    game_scores = relationship(
        "GameScore", back_populates="user", cascade="all, delete-orphan"
    )
    qalqan_profile = relationship(
        "QalqanProfile", back_populates="user", cascade="all, delete-orphan",
        uselist=False,
    )
    qalqan_parents = relationship(
        "QalqanParentPhone", back_populates="child", cascade="all, delete-orphan"
    )


# ---------------------------------------------------------------------------
# Static Learning Content (seeded once)
# ---------------------------------------------------------------------------

class Phase(Base):
    __tablename__ = "phases"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    title_translations: Mapped[dict] = mapped_column(JSON, nullable=False)
    internal_cefr_level: Mapped[str] = mapped_column(String(10), nullable=False)
    required_lessons_to_pass: Mapped[int] = mapped_column(Integer, default=80)

    categories = relationship("Category", back_populates="phase")


class Category(Base):
    __tablename__ = "categories"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    phase_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("phases.id"), index=True, nullable=False
    )
    name_translations: Mapped[dict] = mapped_column(JSON, nullable=False)
    icon_name: Mapped[str] = mapped_column(String(100), nullable=False)

    phase = relationship("Phase", back_populates="categories")
    lessons = relationship("Lesson", back_populates="category")


class Lesson(Base):
    __tablename__ = "lessons"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    category_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("categories.id"), index=True, nullable=False
    )
    # Multilingual lesson title — keys are language codes ("en", "ru", "kk").
    topic_translations: Mapped[dict] = mapped_column(JSON, nullable=False)
    order_index: Mapped[int] = mapped_column(Integer, nullable=False)

    category = relationship("Category", back_populates="lessons")
    items = relationship("Item", back_populates="lesson")


class Item(Base):
    __tablename__ = "items"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    lesson_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("lessons.id"), index=True, nullable=False
    )
    # word | grammar_rule | sentence
    item_type: Mapped[str] = mapped_column(String(50), index=True, nullable=False)
    text_content: Mapped[str] = mapped_column(Text, nullable=False)
    translations: Mapped[dict] = mapped_column(JSON, nullable=False)
    extra_data_json: Mapped[dict | None] = mapped_column(JSON, nullable=True)

    lesson = relationship("Lesson", back_populates="items")


# ---------------------------------------------------------------------------
# Progress Tracking
# ---------------------------------------------------------------------------

class UserCompletedLesson(Base):
    __tablename__ = "user_completed_lessons"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("users.id"), index=True, nullable=False
    )
    lesson_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("lessons.id"), index=True, nullable=False
    )
    completed_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow
    )

    __table_args__ = (
        UniqueConstraint("user_id", "lesson_id", name="uq_user_lesson"),
    )

    user = relationship("User", back_populates="completed_lessons")
    lesson = relationship("Lesson")


class UserLearnedItem(Base):
    """SM-2 inspired spaced-repetition record per (user, item)."""
    __tablename__ = "user_learned_items"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("users.id"), index=True, nullable=False
    )
    item_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("items.id"), index=True, nullable=False
    )
    mistakes_count: Mapped[int] = mapped_column(Integer, default=0)
    correct_streak: Mapped[int] = mapped_column(Integer, default=0)
    ease_factor: Mapped[float] = mapped_column(Float, default=2.5)
    interval_days: Mapped[int] = mapped_column(Integer, default=0)
    last_reviewed_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    next_review_date: Mapped[date | None] = mapped_column(
        Date, index=True, nullable=True
    )

    __table_args__ = (
        UniqueConstraint("user_id", "item_id", name="uq_user_item"),
    )

    user = relationship("User", back_populates="learned_items")
    item = relationship("Item")


class GameScore(Base):
    """Best score achieved per user per game type.

    One row per (user, game_type) — replaces the denormalised
    `match_highscore` / `sprint_highscore` columns on `users`.
    """
    __tablename__ = "game_scores"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("users.id"), index=True, nullable=False
    )
    game_type: Mapped[str] = mapped_column(String(50), nullable=False)
    highscore: Mapped[int] = mapped_column(Integer, default=0)
    plays_count: Mapped[int] = mapped_column(Integer, default=0)
    last_played_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow
    )

    __table_args__ = (
        UniqueConstraint("user_id", "game_type", name="uq_user_game"),
        Index("ix_game_scores_user_game", "user_id", "game_type"),
    )

    user = relationship("User", back_populates="game_scores")


# ---------------------------------------------------------------------------
# Qalqan Family Protection MVP
# ---------------------------------------------------------------------------

class QalqanProfile(Base):
    """Subscription and child contact settings for Qalqan."""
    __tablename__ = "qalqan_profiles"

    user_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("users.id"), primary_key=True
    )
    subscription_plan: Mapped[str] = mapped_column(String(20), default="personal")
    child_phone: Mapped[str | None] = mapped_column(String(32), nullable=True)
    telegram_chat_id: Mapped[str | None] = mapped_column(String(64), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, onupdate=datetime.utcnow
    )

    user = relationship("User", back_populates="qalqan_profile")


class QalqanParentPhone(Base):
    """Parent phone bound to a child's subscription."""
    __tablename__ = "qalqan_parent_phones"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    child_user_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("users.id"), index=True, nullable=False
    )
    phone: Mapped[str] = mapped_column(String(32), nullable=False)
    display_name: Mapped[str | None] = mapped_column(String(100), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    __table_args__ = (
        UniqueConstraint("child_user_id", "phone", name="uq_qalqan_child_parent_phone"),
    )

    child = relationship("User", back_populates="qalqan_parents")


class QalqanAlertLog(Base):
    """Audit trail for fraud triggers sent by the parent device."""
    __tablename__ = "qalqan_alert_logs"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    child_user_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("users.id"), index=True, nullable=False
    )
    parent_phone: Mapped[str | None] = mapped_column(String(32), nullable=True)
    alert_type: Mapped[str] = mapped_column(String(32), nullable=False)
    sender: Mapped[str | None] = mapped_column(String(64), nullable=True)
    code: Mapped[str | None] = mapped_column(String(16), nullable=True)
    trigger_phrase: Mapped[str | None] = mapped_column(String(100), nullable=True)
    message: Mapped[str] = mapped_column(Text, nullable=False)
    telegram_sent: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
