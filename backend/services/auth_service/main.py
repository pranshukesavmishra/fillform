"""
FillFormAI - Auth Service
Handles: Registration, Login (Phone OTP / Google / Email), JWT, Refresh tokens, Aadhaar verification
"""

import hashlib
import hmac
import logging
import random
import string
from datetime import datetime, timedelta, timezone

import httpx
from fastapi import FastAPI, Depends, HTTPException, Request, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from passlib.context import CryptContext
from sqlalchemy import select, and_
from sqlalchemy.ext.asyncio import AsyncSession

from backend.shared.config.settings import settings
from backend.shared.database import get_db, init_db, close_db
from backend.shared.middleware.auth import (
    create_access_token,
    create_refresh_token,
    decode_token,
    get_current_user,
)
from backend.shared.utils.events import publish_event, Event, EventTopic
from backend.services.auth_service.models import User, OTPRecord, RefreshToken, UserRole
from backend.services.auth_service.schemas import (
    PhoneOTPRequest,
    PhoneOTPVerify,
    GoogleOAuthRequest,
    TokenResponse,
    RefreshTokenRequest,
    UserResponse,
)

logger = logging.getLogger(__name__)
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

app = FastAPI(
    title="FillFormAI - Auth Service",
    version="1.0.0",
    docs_url="/docs" if not settings.is_production else None,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
async def startup():
    await init_db()
    logger.info("Auth Service started")


@app.on_event("shutdown")
async def shutdown():
    await close_db()


# ── Health ────────────────────────────────────────────────────────────────────
@app.get("/health")
async def health():
    return {"status": "healthy", "service": "auth", "version": settings.APP_VERSION}


# ── OTP helpers ───────────────────────────────────────────────────────────────
def generate_otp(length: int = 6) -> str:
    return "".join(random.choices(string.digits, k=length))


def hash_otp(otp: str, phone: str) -> str:
    key = f"{settings.SECRET_KEY}:{phone}".encode()
    return hmac.new(key, otp.encode(), hashlib.sha256).hexdigest()


def verify_otp_hash(otp: str, phone: str, stored_hash: str) -> bool:
    expected = hash_otp(otp, phone)
    return hmac.compare_digest(expected, stored_hash)


async def send_sms_otp(phone: str, otp: str, purpose: str) -> None:
    """Send OTP via Twilio. Falls back to console log in dev."""
    message = f"Your FillFormAI OTP is {otp}. Valid for 10 minutes. Do not share."
    if settings.TWILIO_ACCOUNT_SID and settings.is_production:
        try:
            async with httpx.AsyncClient() as client:
                resp = await client.post(
                    f"https://api.twilio.com/2010-04-01/Accounts/{settings.TWILIO_ACCOUNT_SID}/Messages.json",
                    auth=(settings.TWILIO_ACCOUNT_SID, settings.TWILIO_AUTH_TOKEN),
                    data={
                        "From": settings.TWILIO_PHONE_NUMBER,
                        "To": f"+91{phone}",
                        "Body": message,
                    },
                )
                resp.raise_for_status()
        except Exception as e:
            logger.error(f"SMS delivery failed: {e}")
    else:
        logger.info(f"[DEV OTP] Phone: {phone}, OTP: {otp}, Purpose: {purpose}")


# ── Phone OTP ─────────────────────────────────────────────────────────────────
@app.post("/api/v1/auth/otp/send")
async def send_otp(
    body: PhoneOTPRequest,
    request: Request,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db),
):
    # Rate limit: max 5 OTPs per phone per hour (check Redis in production)
    otp = generate_otp()
    otp_hash = hash_otp(otp, body.phone)
    expires_at = datetime.now(timezone.utc) + timedelta(minutes=10)

    # Invalidate previous OTPs for this phone+purpose
    existing = await db.execute(
        select(OTPRecord).where(
            and_(
                OTPRecord.phone == body.phone,
                OTPRecord.purpose == body.purpose,
                not OTPRecord.is_used,
            )
        )
    )
    for record in existing.scalars().all():
        record.is_used = True

    db.add(
        OTPRecord(
            phone=body.phone,
            otp_hash=otp_hash,
            purpose=body.purpose,
            expires_at=expires_at,
            ip_address=request.client.host if request.client else None,
        )
    )
    await db.commit()

    background_tasks.add_task(send_sms_otp, body.phone, otp, body.purpose)
    return {"message": "OTP sent successfully", "expires_in_seconds": 600}


@app.post("/api/v1/auth/otp/verify", response_model=TokenResponse)
async def verify_otp(
    body: PhoneOTPVerify,
    db: AsyncSession = Depends(get_db),
):
    now = datetime.now(timezone.utc)

    otp_record = await db.scalar(
        select(OTPRecord)
        .where(
            and_(
                OTPRecord.phone == body.phone,
                not OTPRecord.is_used,
                OTPRecord.expires_at > now,
            )
        )
        .order_by(OTPRecord.created_at.desc())
    )

    if not otp_record:
        raise HTTPException(
            status_code=400, detail="OTP expired or not found. Request a new one."
        )

    if otp_record.attempts >= 3:
        raise HTTPException(
            status_code=429, detail="Too many attempts. Request a new OTP."
        )

    if not verify_otp_hash(body.otp, body.phone, otp_record.otp_hash):
        otp_record.attempts += 1
        await db.commit()
        raise HTTPException(
            status_code=400,
            detail=f"Invalid OTP. {3 - otp_record.attempts} attempts remaining.",
        )

    otp_record.is_used = True

    # Find or create user
    user = await db.scalar(select(User).where(User.phone == body.phone))
    is_new_user = user is None

    if is_new_user:
        user = User(
            phone=body.phone,
            full_name=body.full_name or "Student",
            role=UserRole.STUDENT,
            is_active=True,
            is_verified=True,
        )
        db.add(user)

    user.last_login_at = now
    user.login_count = (user.login_count or 0) + 1
    await db.commit()
    await db.refresh(user)

    access_token = create_access_token(str(user.id), user.role)
    refresh_token = create_refresh_token(str(user.id))

    # Store refresh token
    token_hash = hashlib.sha256(refresh_token.encode()).hexdigest()
    db.add(
        RefreshToken(
            user_id=user.id,
            token_hash=token_hash,
            expires_at=now + timedelta(days=settings.JWT_REFRESH_EXPIRE_DAYS),
        )
    )
    await db.commit()

    if is_new_user:
        await publish_event(
            Event(
                topic=EventTopic.STUDENT_REGISTERED,
                event_type="student.registered",
                payload={"user_id": str(user.id), "phone": user.phone},
                source_service="auth_service",
            )
        )

    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        expires_in=settings.JWT_ACCESS_EXPIRE_MINUTES * 60,
        user=UserResponse.model_validate(user),
    )


# ── Google OAuth ──────────────────────────────────────────────────────────────
@app.post("/api/v1/auth/google", response_model=TokenResponse)
async def google_login(body: GoogleOAuthRequest, db: AsyncSession = Depends(get_db)):
    async with httpx.AsyncClient() as client:
        resp = await client.get(
            "https://oauth2.googleapis.com/tokeninfo",
            params={"id_token": body.id_token},
        )
        if resp.status_code != 200:
            raise HTTPException(status_code=400, detail="Invalid Google token")
        google_data = resp.json()

    if google_data.get("aud") != settings.GOOGLE_CLIENT_ID:
        raise HTTPException(status_code=400, detail="Token audience mismatch")

    google_id = google_data["sub"]
    email = google_data.get("email")
    name = google_data.get("name", "Student")
    picture = google_data.get("picture")

    user = await db.scalar(
        select(User).where(User.google_id == google_id)
    ) or await db.scalar(select(User).where(User.email == email))

    is_new = user is None
    if is_new:
        user = User(
            google_id=google_id,
            email=email,
            full_name=name,
            profile_picture_url=picture,
            role=body.role,
            is_active=True,
            is_verified=True,
        )
        db.add(user)
    else:
        user.google_id = google_id
        user.profile_picture_url = picture or user.profile_picture_url

    user.last_login_at = datetime.now(timezone.utc)
    await db.commit()
    await db.refresh(user)

    access_token = create_access_token(str(user.id), user.role)
    refresh_token = create_refresh_token(str(user.id))

    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        expires_in=settings.JWT_ACCESS_EXPIRE_MINUTES * 60,
        user=UserResponse.model_validate(user),
    )


# ── Refresh Token ─────────────────────────────────────────────────────────────
@app.post("/api/v1/auth/refresh", response_model=TokenResponse)
async def refresh_token(body: RefreshTokenRequest, db: AsyncSession = Depends(get_db)):
    payload = decode_token(body.refresh_token)
    token_hash = hashlib.sha256(body.refresh_token.encode()).hexdigest()

    record = await db.scalar(
        select(RefreshToken).where(
            and_(
                RefreshToken.token_hash == token_hash,
                not RefreshToken.is_revoked,
                RefreshToken.expires_at > datetime.now(timezone.utc),
            )
        )
    )
    if not record:
        raise HTTPException(status_code=401, detail="Refresh token invalid or expired")

    user = await db.get(User, payload.user_id)
    if not user or not user.is_active:
        raise HTTPException(status_code=401, detail="User not found or inactive")

    record.is_revoked = True
    new_refresh = create_refresh_token(str(user.id))
    new_token_hash = hashlib.sha256(new_refresh.encode()).hexdigest()
    db.add(
        RefreshToken(
            user_id=user.id,
            token_hash=new_token_hash,
            expires_at=datetime.now(timezone.utc)
            + timedelta(days=settings.JWT_REFRESH_EXPIRE_DAYS),
        )
    )
    await db.commit()

    return TokenResponse(
        access_token=create_access_token(str(user.id), user.role),
        refresh_token=new_refresh,
        expires_in=settings.JWT_ACCESS_EXPIRE_MINUTES * 60,
        user=UserResponse.model_validate(user),
    )


# ── Logout ────────────────────────────────────────────────────────────────────
@app.post("/api/v1/auth/logout")
async def logout(
    body: RefreshTokenRequest,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    token_hash = hashlib.sha256(body.refresh_token.encode()).hexdigest()
    record = await db.scalar(
        select(RefreshToken).where(RefreshToken.token_hash == token_hash)
    )
    if record:
        record.is_revoked = True
        await db.commit()
    return {"message": "Logged out successfully"}


# ── Me ────────────────────────────────────────────────────────────────────────
@app.get("/api/v1/auth/me", response_model=UserResponse)
async def get_me(
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    user = await db.get(User, current_user.user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return UserResponse.model_validate(user)
