"""
FillFormAI - Payment Service (port 8009)
Handles: Razorpay orders for agent sessions, premium subscriptions, refunds
"""
import hashlib
import hmac
import logging
import uuid
from typing import Optional

import httpx
from fastapi import FastAPI, Depends, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from sqlalchemy import text

from backend.shared.config.settings import settings
from backend.shared.database import get_db
from backend.shared.middleware.auth import get_current_user

logger = logging.getLogger(__name__)

app = FastAPI(title="FillFormAI - Payment Service", version="1.0.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

RAZORPAY_BASE = "https://api.razorpay.com/v1"

PLAN_PRICES = {
    "free": 0,
    "pro_monthly": 99,       # ₹99/month
    "pro_yearly": 799,       # ₹799/year (~₹67/month)
    "premium_monthly": 299,
    "premium_yearly": 2499,
}


# ── Models ─────────────────────────────────────────────────────────────────────

class CreateOrderRequest(BaseModel):
    amount_paise: int = Field(..., gt=0, description="Amount in paise (₹1 = 100 paise)")
    currency: str = "INR"
    purpose: str = Field(..., description="agent_session|subscription|document_service")
    reference_id: Optional[str] = None  # session_id or subscription plan id
    notes: dict = {}


class VerifyPaymentRequest(BaseModel):
    razorpay_order_id: str
    razorpay_payment_id: str
    razorpay_signature: str
    internal_order_id: str


class SubscriptionRequest(BaseModel):
    plan: str = Field(..., pattern="^(pro_monthly|pro_yearly|premium_monthly|premium_yearly)$")


# ── Razorpay helpers ───────────────────────────────────────────────────────────

def _rz_auth():
    if not settings.razorpay_key_id or not settings.razorpay_key_secret:
        raise HTTPException(503, "Payment gateway not configured")
    return (settings.razorpay_key_id, settings.razorpay_key_secret)


async def _create_rz_order(amount_paise: int, currency: str, receipt: str, notes: dict) -> dict:
    auth = _rz_auth()
    async with httpx.AsyncClient() as client:
        resp = await client.post(
            f"{RAZORPAY_BASE}/orders",
            auth=auth,
            json={
                "amount": amount_paise,
                "currency": currency,
                "receipt": receipt,
                "notes": notes,
            },
            timeout=10,
        )
    if resp.status_code != 200:
        logger.error(f"Razorpay order creation failed: {resp.text}")
        raise HTTPException(502, "Payment gateway error")
    return resp.json()


def _verify_signature(order_id: str, payment_id: str, signature: str) -> bool:
    secret = settings.razorpay_key_secret
    if not secret:
        return False
    msg = f"{order_id}|{payment_id}"
    expected = hmac.new(secret.encode(), msg.encode(), hashlib.sha256).hexdigest()
    return hmac.compare_digest(expected, signature)


# ── Endpoints ──────────────────────────────────────────────────────────────────

@app.get("/health")
async def health():
    return {"status": "ok", "service": "payment-service"}


@app.post("/api/v1/payments/order/create")
async def create_payment_order(
    body: CreateOrderRequest,
    db=Depends(get_db),
    current_user=Depends(get_current_user),
):
    """Create a Razorpay order. Returns order_id for frontend checkout."""
    receipt = f"ff_{current_user.user_id}_{uuid.uuid4().hex[:8]}"
    internal_id = uuid.uuid4()

    rz_order = await _create_rz_order(
        amount_paise=body.amount_paise,
        currency=body.currency,
        receipt=receipt,
        notes={**body.notes, "user_id": str(current_user.user_id), "purpose": body.purpose},
    )

    # Record in DB
    await db.execute(
        text("""
            INSERT INTO payment_orders
                (id, user_id, razorpay_order_id, amount_paise, currency, purpose,
                 reference_id, status, created_at)
            VALUES
                (:id, :uid, :rz_id, :amount, :currency, :purpose, :ref_id, 'created', NOW())
        """),
        {
            "id": internal_id,
            "uid": current_user.user_id,
            "rz_id": rz_order["id"],
            "amount": body.amount_paise,
            "currency": body.currency,
            "purpose": body.purpose,
            "ref_id": body.reference_id,
        },
    )
    await db.commit()

    return {
        "internal_order_id": str(internal_id),
        "razorpay_order_id": rz_order["id"],
        "amount_paise": body.amount_paise,
        "currency": body.currency,
        "razorpay_key_id": settings.razorpay_key_id,
    }


@app.post("/api/v1/payments/verify")
async def verify_payment(
    body: VerifyPaymentRequest,
    db=Depends(get_db),
    current_user=Depends(get_current_user),
):
    """Verify Razorpay payment signature and mark order as paid."""
    if not _verify_signature(body.razorpay_order_id, body.razorpay_payment_id, body.razorpay_signature):
        raise HTTPException(400, "Payment verification failed — invalid signature")

    # Get our order record
    order_r = await db.execute(
        text("SELECT * FROM payment_orders WHERE id = :id AND user_id = :uid"),
        {"id": body.internal_order_id, "uid": current_user.user_id},
    )
    order = order_r.fetchone()
    if not order:
        raise HTTPException(404, "Order not found")
    if order.status == "paid":
        return {"success": True, "already_paid": True}

    # Mark paid
    await db.execute(
        text("""
            UPDATE payment_orders
            SET status = 'paid', razorpay_payment_id = :payment_id, paid_at = NOW()
            WHERE id = :id
        """),
        {"id": body.internal_order_id, "payment_id": body.razorpay_payment_id},
    )

    # Fulfill based on purpose
    if order.purpose == "agent_session" and order.reference_id:
        await db.execute(
            text("UPDATE agent_sessions SET payment_status = 'paid', status = 'confirmed' WHERE id = :id"),
            {"id": order.reference_id},
        )
    elif order.purpose == "subscription" and order.reference_id:
        from datetime import date, timedelta
        plan = order.reference_id
        days = 365 if "yearly" in plan else 30
        await db.execute(
            text("""
                INSERT INTO subscriptions (id, user_id, plan, started_at, expires_at, status)
                VALUES (gen_random_uuid(), :uid, :plan, NOW(), NOW() + :days * INTERVAL '1 day', 'active')
                ON CONFLICT (user_id) DO UPDATE
                SET plan = EXCLUDED.plan, expires_at = EXCLUDED.expires_at, status = 'active'
            """),
            {"uid": current_user.user_id, "plan": plan, "days": days},
        )

    await db.commit()
    logger.info(f"Payment verified: order {body.internal_order_id}, payment {body.razorpay_payment_id}")
    return {"success": True, "purpose": order.purpose, "reference_id": order.reference_id}


@app.post("/api/v1/payments/webhook")
async def razorpay_webhook(request: Request, db=Depends(get_db)):
    """Razorpay webhook for async payment events."""
    payload = await request.body()
    sig = request.headers.get("X-Razorpay-Signature", "")

    if settings.razorpay_webhook_secret:
        expected = hmac.new(
            settings.razorpay_webhook_secret.encode(),
            payload,
            hashlib.sha256,
        ).hexdigest()
        if not hmac.compare_digest(expected, sig):
            raise HTTPException(400, "Invalid webhook signature")

    event = await request.json()
    event_type = event.get("event")
    logger.info(f"Razorpay webhook: {event_type}")

    if event_type == "payment.failed":
        payment = event["payload"]["payment"]["entity"]
        order_id = payment.get("order_id")
        if order_id:
            await db.execute(
                text("UPDATE payment_orders SET status = 'failed' WHERE razorpay_order_id = :oid"),
                {"oid": order_id},
            )
            await db.commit()

    return {"status": "ok"}


@app.get("/api/v1/payments/history")
async def payment_history(
    db=Depends(get_db),
    current_user=Depends(get_current_user),
):
    result = await db.execute(
        text("""
            SELECT id, razorpay_order_id, razorpay_payment_id, amount_paise,
                   currency, purpose, reference_id, status, paid_at, created_at
            FROM payment_orders
            WHERE user_id = :uid
            ORDER BY created_at DESC
            LIMIT 50
        """),
        {"uid": current_user.user_id},
    )
    rows = result.fetchall()
    return {"payments": [dict(r._mapping) for r in rows]}


@app.get("/api/v1/payments/subscription/status")
async def subscription_status(
    db=Depends(get_db),
    current_user=Depends(get_current_user),
):
    result = await db.execute(
        text("SELECT plan, started_at, expires_at, status FROM subscriptions WHERE user_id = :uid AND status = 'active'"),
        {"uid": current_user.user_id},
    )
    sub = result.fetchone()
    if not sub:
        return {"plan": "free", "is_active": False}

    from datetime import date
    is_active = sub.expires_at >= date.today() if sub.expires_at else False
    return {
        "plan": sub.plan,
        "is_active": is_active,
        "started_at": str(sub.started_at),
        "expires_at": str(sub.expires_at),
    }


@app.get("/api/v1/payments/plans")
async def list_plans():
    return {
        "plans": [
            {
                "id": "free",
                "name": "Free",
                "price_monthly": 0,
                "features": ["5 applications/month", "Basic AI form fill", "Document vault (5 docs)"],
            },
            {
                "id": "pro_monthly",
                "name": "Pro Monthly",
                "price_monthly": 99,
                "price_paise": 9900,
                "features": ["Unlimited applications", "Full AI features", "WhatsApp alerts", "Priority support"],
            },
            {
                "id": "pro_yearly",
                "name": "Pro Yearly",
                "price_monthly": 67,
                "price_paise": 79900,
                "features": ["Everything in Pro", "2 free agent sessions/year", "Best value"],
                "badge": "Best Value",
            },
        ]
    }
