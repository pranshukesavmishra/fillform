"""
FillFormAI - Notification Service (port 8007)
Handles: Push (FCM), WhatsApp, SMS (Twilio), Email (SendGrid), in-app
Document expiry scheduler runs here daily at 9 AM IST.
"""

import logging
from contextlib import asynccontextmanager
from typing import Optional

import httpx
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from fastapi import FastAPI, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from backend.shared.config.settings import settings
from backend.shared.database import get_db
from backend.shared.middleware.auth import get_current_user
from backend.services.notification_service.expiry_scheduler import (
    setup_expiry_scheduler,
)

logger = logging.getLogger(__name__)

_scheduler: AsyncIOScheduler | None = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    global _scheduler
    _scheduler = setup_expiry_scheduler(app, get_db)
    _scheduler.start()
    logger.info(
        "Notification service started — expiry scheduler active (daily 9 AM IST)"
    )
    yield
    if _scheduler:
        _scheduler.shutdown(wait=False)


app = FastAPI(
    title="FillFormAI - Notification Service",
    version="1.0.0",
    lifespan=lifespan,
)
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ── Pydantic Models ────────────────────────────────────────────────────────────


class PushNotificationRequest(BaseModel):
    user_id: str
    title: str = Field(..., max_length=100)
    body: str = Field(..., max_length=500)
    data: dict = {}
    image_url: Optional[str] = None


class WhatsAppMessageRequest(BaseModel):
    phone: str = Field(..., description="Phone in E.164 format, e.g. +919876543210")
    message: str = Field(..., max_length=4000)
    template_name: Optional[str] = None
    template_params: list[str] = []


class SMSRequest(BaseModel):
    phone: str
    message: str = Field(..., max_length=160)


class BulkNotificationRequest(BaseModel):
    user_ids: list[str]
    title: str
    body: str
    channels: list[str] = ["push", "in_app"]
    data: dict = {}


class ManualExpiryCheckRequest(BaseModel):
    dry_run: bool = True  # If true, returns what would be sent without sending


# ── Health ─────────────────────────────────────────────────────────────────────


@app.get("/health")
async def health():
    scheduler_running = _scheduler.running if _scheduler else False
    next_run = None
    if _scheduler:
        job = _scheduler.get_job("document_expiry_check")
        if job:
            next_run = str(job.next_run_time)
    return {
        "status": "ok",
        "service": "notification-service",
        "scheduler_running": scheduler_running,
        "next_expiry_check": next_run,
    }


# ── Push Notifications ─────────────────────────────────────────────────────────


@app.post("/api/v1/notifications/push")
async def send_push_notification(
    body: PushNotificationRequest,
    current_user=Depends(get_current_user),
):
    """Send FCM push notification to a user's device."""
    if not settings.fcm_server_key:
        logger.warning("FCM server key not configured — push skipped")
        return {"sent": False, "reason": "FCM not configured"}

    async with httpx.AsyncClient() as client:
        response = await client.post(
            "https://fcm.googleapis.com/fcm/send",
            headers={
                "Authorization": f"key={settings.fcm_server_key}",
                "Content-Type": "application/json",
            },
            json={
                "to": "/topics/" + body.user_id,  # Topic-based; device token in prod
                "notification": {
                    "title": body.title,
                    "body": body.body,
                    "image": body.image_url,
                },
                "data": body.data,
                "priority": "high",
            },
            timeout=10,
        )

    if response.status_code != 200:
        logger.error(f"FCM error {response.status_code}: {response.text}")
        raise HTTPException(502, "Push notification delivery failed")

    return {"sent": True, "fcm_response": response.json()}


# ── WhatsApp ───────────────────────────────────────────────────────────────────


@app.post("/api/v1/notifications/whatsapp")
async def send_whatsapp(
    body: WhatsAppMessageRequest,
    current_user=Depends(get_current_user),
):
    """
    Send WhatsApp message via Meta Cloud API.
    Supports free-text (within 24h session) and template messages.
    """
    if not settings.whatsapp_business_token:
        logger.warning("WhatsApp token not configured")
        return {"sent": False, "reason": "WhatsApp not configured"}

    phone_id = settings.whatsapp_phone_number_id
    url = f"https://graph.facebook.com/v19.0/{phone_id}/messages"

    if body.template_name:
        payload = {
            "messaging_product": "whatsapp",
            "to": body.phone,
            "type": "template",
            "template": {
                "name": body.template_name,
                "language": {"code": "en_IN"},
                "components": [
                    {
                        "type": "body",
                        "parameters": [
                            {"type": "text", "text": p} for p in body.template_params
                        ],
                    }
                ]
                if body.template_params
                else [],
            },
        }
    else:
        payload = {
            "messaging_product": "whatsapp",
            "to": body.phone,
            "type": "text",
            "text": {"preview_url": False, "body": body.message},
        }

    async with httpx.AsyncClient() as client:
        resp = await client.post(
            url,
            headers={"Authorization": f"Bearer {settings.whatsapp_business_token}"},
            json=payload,
            timeout=10,
        )

    if resp.status_code not in (200, 201):
        logger.error(f"WhatsApp API error: {resp.text}")
        raise HTTPException(502, "WhatsApp delivery failed")

    return {"sent": True, "wa_id": resp.json().get("messages", [{}])[0].get("id")}


# ── SMS (Twilio) ───────────────────────────────────────────────────────────────


@app.post("/api/v1/notifications/sms")
async def send_sms(
    body: SMSRequest,
    current_user=Depends(get_current_user),
):
    """Send SMS via Twilio."""
    if not settings.twilio_account_sid:
        logger.warning("Twilio not configured — SMS skipped")
        return {"sent": False, "reason": "Twilio not configured"}

    async with httpx.AsyncClient() as client:
        resp = await client.post(
            f"https://api.twilio.com/2010-04-01/Accounts/{settings.twilio_account_sid}/Messages.json",
            auth=(settings.twilio_account_sid, settings.twilio_auth_token),
            data={
                "From": settings.twilio_phone_number,
                "To": body.phone if body.phone.startswith("+") else f"+91{body.phone}",
                "Body": body.message,
            },
            timeout=10,
        )

    if resp.status_code not in (200, 201):
        raise HTTPException(502, f"SMS failed: {resp.text}")

    return {"sent": True, "sid": resp.json().get("sid")}


# ── Document Expiry Alerts (manual trigger for testing) ───────────────────────


@app.post("/api/v1/notifications/expiry-check")
async def trigger_expiry_check(
    body: ManualExpiryCheckRequest,
    db=Depends(get_db),
    current_user=Depends(get_current_user),
):
    """
    Manually trigger document expiry check.
    Used by admins and for testing. Normally runs automatically at 9 AM daily.
    """
    if current_user.role not in ("admin",):
        raise HTTPException(403, "Admin only")

    if body.dry_run:
        from sqlalchemy import text
        from datetime import date, timedelta

        today = date.today()
        results = []
        for days in [30, 15, 7, 0]:
            target = today + timedelta(days=days)
            r = await db.execute(
                text("""
                    SELECT d.document_type, d.expires_at, u.full_name, u.phone
                    FROM documents d JOIN users u ON d.user_id = u.id
                    WHERE d.expires_at = :t AND NOT d.is_expired
                    LIMIT 20
                """),
                {"t": target},
            )
            rows = r.fetchall()
            results.append(
                {
                    "days_remaining": days,
                    "documents_expiring": [
                        {
                            "doc_type": row.document_type,
                            "expiry": str(row.expires_at),
                            "name": row.full_name,
                            "phone": row.phone,
                        }
                        for row in rows
                    ],
                }
            )
        return {"dry_run": True, "would_alert": results}

    from backend.services.notification_service.expiry_scheduler import (
        check_and_send_expiry_alerts,
    )

    result = await check_and_send_expiry_alerts(db)
    return {"dry_run": False, "alerts_sent": result}
