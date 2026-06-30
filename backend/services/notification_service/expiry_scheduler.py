"""
Document Expiry Alert Scheduler

Runs as a background task (APScheduler) inside the notification service.
Checks all documents nearing expiry and sends multi-channel alerts.

Alert schedule:
  - 30 days before: WhatsApp + push notification
  - 15 days before: WhatsApp + push + SMS
  - 7 days before:  WhatsApp + push + SMS + in-app banner
  - 0 days (expired): In-app blocking banner + WhatsApp

Each alert is sent only once per (document_id, days_remaining) pair to avoid spam.
"""
import logging
from datetime import date, timedelta

from apscheduler.schedulers.asyncio import AsyncIOScheduler
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession


logger = logging.getLogger(__name__)

# Document type → human-readable name + renewal guide
DOCUMENT_META = {
    "aadhaar":              ("Aadhaar Card",           None),  # Aadhaar doesn't expire but address update needed
    "income_certificate":  ("Income Certificate",      "https://edistrict.up.gov.in"),
    "caste_certificate":   ("Caste Certificate",       "https://edistrict.up.gov.in"),
    "domicile_certificate":("Domicile Certificate",    "https://edistrict.up.gov.in"),
    "10th_marksheet":      ("10th Marksheet",          None),  # Permanent
    "12th_marksheet":      ("12th Marksheet",          None),  # Permanent
    "bank_passbook":       ("Bank Passbook",           None),
    "scholarship_sanction":("Scholarship Sanction Letter", None),
    "bonafide":            ("Bonafide Certificate",    None),  # Renew each academic year
    "character_certificate":("Character Certificate", None),
}

ALERT_DAYS = [30, 15, 7, 0]

ALERT_TEMPLATES = {
    30: {
        "title": "📄 Document Expiring in 30 Days",
        "body_template": "Your {doc_name} expires on {expiry_date}. Renew it now to keep your scholarship applications running smoothly.",
        "whatsapp_template": "🔔 *FillFormAI Alert*\n\nYour *{doc_name}* expires on *{expiry_date}* (30 days left).\n\nRenew it early to avoid missing scholarships!\n\n{renewal_link}\n\n_Open FillFormAI to upload the renewed document._",
        "urgency": "normal",
    },
    15: {
        "title": "⚠️ Document Expiring in 15 Days — Action Required",
        "body_template": "Your {doc_name} expires on {expiry_date}. 3 active scholarship applications require this document. Renew NOW.",
        "whatsapp_template": "⚠️ *URGENT — FillFormAI*\n\nYour *{doc_name}* expires on *{expiry_date}* (only 15 days left)!\n\nThis document is required for your active scholarship applications. Please renew immediately.\n\n{renewal_link}\n\n_Tap to open FillFormAI_",
        "urgency": "high",
    },
    7: {
        "title": "🚨 URGENT: Document Expires in 7 Days",
        "body_template": "URGENT: Your {doc_name} expires in 7 days. Your applications may be rejected without it.",
        "whatsapp_template": "🚨 *CRITICAL — FillFormAI*\n\nYour *{doc_name}* expires in *7 DAYS* ({expiry_date})!\n\nIf not renewed, your scholarship applications will be rejected. Please renew TODAY.\n\n{renewal_link}\n\nNeed help? Book an agent session: fillformai.in/agents",
        "urgency": "critical",
    },
    0: {
        "title": "❌ Document Expired — Applications Paused",
        "body_template": "Your {doc_name} has expired. Upload the renewed document to resume your applications.",
        "whatsapp_template": "❌ *FillFormAI — Document Expired*\n\nYour *{doc_name}* has expired as of today.\n\nYour scholarship applications have been paused. Please renew and upload the new document.\n\n{renewal_link}\n\nNeed help renewing? Our agents can guide you: fillformai.in/agents",
        "urgency": "critical",
    },
}


async def check_and_send_expiry_alerts(db: AsyncSession) -> dict:
    """
    Main scheduler task. Runs daily at 9:00 AM IST.
    Returns summary of alerts sent.
    """
    today = date.today()
    alerts_sent = {"push": 0, "whatsapp": 0, "sms": 0, "in_app": 0, "total_users": 0}

    for days in ALERT_DAYS:
        target_date = today + timedelta(days=days)

        # Find all documents expiring on target_date that haven't been alerted yet
        result = await db.execute(
            text("""
                SELECT
                    d.id,
                    d.user_id,
                    d.document_type,
                    d.expires_at,
                    u.phone,
                    u.fcm_token,
                    u.whatsapp_opted_in,
                    u.preferred_language,
                    u.full_name
                FROM documents d
                JOIN users u ON d.user_id = u.id
                WHERE
                    d.expires_at = :target_date
                    AND d.is_expired = false
                    AND u.is_active = true
                    AND NOT EXISTS (
                        SELECT 1 FROM notifications n
                        WHERE n.user_id = d.user_id
                          AND n.data->>'document_id' = d.id::text
                          AND n.data->>'days_remaining' = :days_str
                          AND n.created_at > NOW() - INTERVAL '25 days'
                    )
            """),
            {"target_date": target_date, "days_str": str(days)},
        )
        documents = result.fetchall()

        for doc in documents:
            doc_meta = DOCUMENT_META.get(doc.document_type, (doc.document_type.replace("_", " ").title(), None))
            doc_name = doc_meta[0]
            renewal_url = doc_meta[1] or "https://edistrict.up.gov.in"
            template = ALERT_TEMPLATES[days]

            body = template["body_template"].format(
                doc_name=doc_name,
                expiry_date=doc.expires_at.strftime("%d %b %Y"),
            )
            whatsapp_body = template["whatsapp_template"].format(
                doc_name=doc_name,
                expiry_date=doc.expires_at.strftime("%d %b %Y"),
                renewal_link=renewal_url,
            )

            notification_data = {
                "document_id": str(doc.id),
                "document_type": doc.document_type,
                "days_remaining": str(days),
                "expiry_date": doc.expires_at.isoformat(),
                "renewal_url": renewal_url,
                "deep_link": f"/documents/{doc.id}/renew",
            }

            # Push notification
            if doc.fcm_token:
                await _send_push(
                    db, doc.user_id, doc.fcm_token,
                    template["title"], body, notification_data
                )
                alerts_sent["push"] += 1

            # WhatsApp (for 15-day, 7-day, and expired alerts)
            if doc.whatsapp_opted_in and days <= 15:
                await _send_whatsapp(db, doc.user_id, doc.phone, whatsapp_body, notification_data)
                alerts_sent["whatsapp"] += 1

            # SMS (for 7-day and expired only)
            if days <= 7:
                sms_body = f"FillFormAI: {doc_name} expires {doc.expires_at.strftime('%d %b')}. Renew: {renewal_url}"
                await _send_sms(db, doc.user_id, doc.phone, sms_body, notification_data)
                alerts_sent["sms"] += 1

            # In-app notification (always)
            await _create_in_app_notification(
                db, doc.user_id, template["title"], body,
                notification_data, template["urgency"]
            )
            alerts_sent["in_app"] += 1
            alerts_sent["total_users"] += 1

    logger.info(f"Expiry alerts sent: {alerts_sent}")
    return alerts_sent


async def _send_push(db, user_id, fcm_token, title, body, data):
    """Insert push notification record. Actual FCM sending handled by worker."""
    await db.execute(
        text("""
            INSERT INTO notifications (id, user_id, type, channel, title, body, data, status, created_at)
            VALUES (gen_random_uuid(), :user_id, 'document_expiry', 'push', :title, :body, :data::jsonb, 'pending', NOW())
        """),
        {"user_id": user_id, "title": title, "body": body, "data": str(data).replace("'", '"')},
    )


async def _send_whatsapp(db, user_id, phone, body, data):
    await db.execute(
        text("""
            INSERT INTO notifications (id, user_id, type, channel, title, body, data, status, created_at)
            VALUES (gen_random_uuid(), :user_id, 'document_expiry', 'whatsapp', 'Document Expiry Alert', :body, :data::jsonb, 'pending', NOW())
        """),
        {"user_id": user_id, "body": body, "data": str(data).replace("'", '"')},
    )


async def _send_sms(db, user_id, phone, body, data):
    await db.execute(
        text("""
            INSERT INTO notifications (id, user_id, type, channel, title, body, data, status, created_at)
            VALUES (gen_random_uuid(), :user_id, 'document_expiry', 'sms', 'Document Expiry', :body, :data::jsonb, 'pending', NOW())
        """),
        {"user_id": user_id, "body": body, "data": str(data).replace("'", '"')},
    )


async def _create_in_app_notification(db, user_id, title, body, data, urgency):
    await db.execute(
        text("""
            INSERT INTO notifications (id, user_id, type, channel, title, body, data, status, created_at)
            VALUES (gen_random_uuid(), :user_id, 'document_expiry', 'in_app', :title, :body, :data::jsonb, 'pending', NOW())
        """),
        {"user_id": user_id, "title": title, "body": body, "data": str(data).replace("'", '"')},
    )
    await db.commit()


def setup_expiry_scheduler(app, get_db_func) -> AsyncIOScheduler:
    """Register the expiry alert job with APScheduler. Call from notification service startup."""
    scheduler = AsyncIOScheduler(timezone="Asia/Kolkata")

    async def _job():
        async for db in get_db_func():
            try:
                result = await check_and_send_expiry_alerts(db)
                logger.info(f"Expiry check complete: {result}")
            except Exception as e:
                logger.error(f"Expiry scheduler error: {e}")
            break

    # Run daily at 9:00 AM IST
    scheduler.add_job(_job, "cron", hour=9, minute=0, id="document_expiry_check")
    return scheduler
