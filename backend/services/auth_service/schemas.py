from pydantic import BaseModel, EmailStr, Field, field_validator
from typing import Optional
from uuid import UUID
import re


class PhoneOTPRequest(BaseModel):
    phone: str = Field(
        ..., pattern=r"^[6-9]\d{9}$", description="10-digit Indian mobile"
    )
    purpose: str = Field(default="login", pattern="^(login|verify|reset)$")

    @field_validator("phone")
    @classmethod
    def normalize_phone(cls, v: str) -> str:
        return v.replace("+91", "").replace(" ", "").strip()


class PhoneOTPVerify(BaseModel):
    phone: str = Field(..., pattern=r"^[6-9]\d{9}$")
    otp: str = Field(..., min_length=6, max_length=6, pattern=r"^\d{6}$")
    full_name: Optional[str] = Field(None, min_length=2, max_length=255)
    referral_code: Optional[str] = None


class GoogleOAuthRequest(BaseModel):
    id_token: str
    role: str = Field(default="student", pattern="^(student|agent)$")


class EmailLoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(..., min_length=8)


class RegisterRequest(BaseModel):
    phone: str = Field(..., pattern=r"^[6-9]\d{9}$")
    full_name: str = Field(..., min_length=2, max_length=255)
    role: str = Field(default="student", pattern="^(student|agent)$")
    referral_code: Optional[str] = None
    preferred_language: str = Field(default="en")


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int
    user: "UserResponse"


class RefreshTokenRequest(BaseModel):
    refresh_token: str


class UserResponse(BaseModel):
    id: UUID
    phone: Optional[str] = None
    email: Optional[str] = None
    full_name: str
    role: str
    is_verified: bool
    is_aadhaar_verified: bool
    profile_picture_url: Optional[str] = None
    preferred_language: str
    whatsapp_opted_in: bool

    class Config:
        from_attributes = True


class DigiLockerCallbackRequest(BaseModel):
    code: str
    state: str


class AadhaarVerifyRequest(BaseModel):
    aadhaar_last4: str = Field(..., min_length=4, max_length=4, pattern=r"^\d{4}$")
    otp: str = Field(..., min_length=6, max_length=6)


class ChangePasswordRequest(BaseModel):
    current_password: str
    new_password: str = Field(..., min_length=8)

    @field_validator("new_password")
    @classmethod
    def validate_password_strength(cls, v: str) -> str:
        if not re.search(r"[A-Z]", v):
            raise ValueError("Password must contain at least one uppercase letter")
        if not re.search(r"\d", v):
            raise ValueError("Password must contain at least one digit")
        return v
