from sqlalchemy import String, Boolean, DateTime, Text, Enum as SAEnum
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.dialects.postgresql import UUID, JSONB
from backend.shared.models.base import BaseModel
from enum import Enum
import uuid


class UserRole(str, Enum):
    STUDENT = "student"
    AGENT = "agent"
    ADMIN = "admin"
    INSTITUTION = "institution"


class AuthProvider(str, Enum):
    EMAIL = "email"
    GOOGLE = "google"
    PHONE = "phone"
    DIGILOCKER = "digilocker"


class User(BaseModel):
    __tablename__ = "users"

    phone: Mapped[str] = mapped_column(String(15), unique=True, nullable=True, index=True)
    email: Mapped[str] = mapped_column(String(255), unique=True, nullable=True, index=True)
    full_name: Mapped[str] = mapped_column(String(255), nullable=False)
    hashed_password: Mapped[str] = mapped_column(String(255), nullable=True)
    role: Mapped[str] = mapped_column(
        SAEnum(UserRole), default=UserRole.STUDENT, nullable=False
    )
    auth_provider: Mapped[str] = mapped_column(
        SAEnum(AuthProvider), default=AuthProvider.PHONE, nullable=False
    )
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    is_verified: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    is_aadhaar_verified: Mapped[bool] = mapped_column(Boolean, default=False)
    aadhaar_last4: Mapped[str] = mapped_column(String(4), nullable=True)
    google_id: Mapped[str] = mapped_column(String(255), nullable=True, unique=True)
    digilocker_id: Mapped[str] = mapped_column(String(255), nullable=True, unique=True)
    last_login_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), nullable=True)
    login_count: Mapped[int] = mapped_column(default=0)
    profile_picture_url: Mapped[str] = mapped_column(Text, nullable=True)
    preferred_language: Mapped[str] = mapped_column(String(10), default="en")
    fcm_token: Mapped[str] = mapped_column(Text, nullable=True)
    whatsapp_opted_in: Mapped[bool] = mapped_column(Boolean, default=False)
    metadata_: Mapped[dict] = mapped_column("metadata", JSONB, default=dict)


class OTPRecord(BaseModel):
    __tablename__ = "otp_records"

    phone: Mapped[str] = mapped_column(String(15), nullable=False, index=True)
    otp_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    purpose: Mapped[str] = mapped_column(String(50), nullable=False)  # login | verify | reset
    expires_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), nullable=False)
    is_used: Mapped[bool] = mapped_column(Boolean, default=False)
    attempts: Mapped[int] = mapped_column(default=0)
    ip_address: Mapped[str] = mapped_column(String(45), nullable=True)


class RefreshToken(BaseModel):
    __tablename__ = "refresh_tokens"

    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False, index=True)
    token_hash: Mapped[str] = mapped_column(String(255), nullable=False, unique=True)
    expires_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), nullable=False)
    is_revoked: Mapped[bool] = mapped_column(Boolean, default=False)
    device_info: Mapped[dict] = mapped_column(JSONB, default=dict)
    ip_address: Mapped[str] = mapped_column(String(45), nullable=True)
