"""SQLAlchemy ORM models for the Qalqan MVP."""
import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Index, Integer, String, Text, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class User(Base):
    """Child account that owns the subscription and alert destination."""
    __tablename__ = "users"

    id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    hashed_password: Mapped[str] = mapped_column(String(255))
    display_name: Mapped[str | None] = mapped_column(String(100), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    qalqan_profile = relationship(
        "QalqanProfile",
        back_populates="user",
        cascade="all, delete-orphan",
        uselist=False,
    )
    qalqan_parents = relationship(
        "QalqanParentPhone",
        back_populates="child",
        cascade="all, delete-orphan",
    )


class QalqanProfile(Base):
    """Subscription and child contact settings."""
    __tablename__ = "qalqan_profiles"

    user_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("users.id"), primary_key=True
    )
    subscription_plan: Mapped[str] = mapped_column(String(20), default="personal")
    subscription_period: Mapped[str] = mapped_column(String(20), default="monthly")
    subscription_status: Mapped[str] = mapped_column(String(20), default="trial")
    subscription_expires_at: Mapped[datetime | None] = mapped_column(
        DateTime, nullable=True
    )
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
        PG_UUID(as_uuid=True), ForeignKey("users.id"), index=True
    )
    phone: Mapped[str] = mapped_column(String(32))
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
        PG_UUID(as_uuid=True), ForeignKey("users.id"), index=True
    )
    parent_phone: Mapped[str | None] = mapped_column(String(32), nullable=True)
    alert_type: Mapped[str] = mapped_column(String(32))
    sender: Mapped[str | None] = mapped_column(String(64), nullable=True)
    code: Mapped[str | None] = mapped_column(String(16), nullable=True)
    trigger_phrase: Mapped[str | None] = mapped_column(String(100), nullable=True)
    message: Mapped[str] = mapped_column(Text)
    telegram_sent: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    __table_args__ = (
        Index("ix_qalqan_alert_logs_child_created", "child_user_id", "created_at"),
    )
