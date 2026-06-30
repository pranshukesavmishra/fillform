"""
FillFormAI - Agent Service (port 8006)
Handles: Human agent marketplace, session booking, ratings, agent chat
Agents = verified humans who help students fill forms, go to govt offices, etc.
"""

import logging
import uuid
from datetime import datetime
from typing import Optional

from fastapi import FastAPI, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from sqlalchemy import text

from backend.shared.config.settings import settings
from backend.shared.database import get_db
from backend.shared.middleware.auth import get_current_user

logger = logging.getLogger(__name__)

app = FastAPI(title="FillFormAI - Agent Service", version="1.0.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ── Models ─────────────────────────────────────────────────────────────────────


class BookSessionRequest(BaseModel):
    agent_id: str
    session_type: str = Field(
        ..., description="video_call|in_person|phone_call|document_pickup"
    )
    scheduled_at: datetime
    duration_minutes: int = Field(default=30, ge=15, le=120)
    issue_description: str = Field(..., min_length=10, max_length=1000)
    documents_needed: list[str] = []
    preferred_language: str = "hi"


class RateAgentRequest(BaseModel):
    session_id: str
    rating: int = Field(..., ge=1, le=5)
    review: Optional[str] = Field(None, max_length=500)
    tags: list[str] = []  # helpful|patient|knowledgeable|on_time|affordable


class AgentFilterRequest(BaseModel):
    district: Optional[str] = None
    specialization: Optional[str] = None
    language: Optional[str] = None
    max_fee: Optional[int] = None
    session_type: Optional[str] = None
    min_rating: float = 3.5


# ── Endpoints ──────────────────────────────────────────────────────────────────


@app.get("/health")
async def health():
    return {"status": "ok", "service": "agent-service"}


@app.get("/api/v1/agents")
async def list_agents(
    district: Optional[str] = None,
    specialization: Optional[str] = None,
    language: Optional[str] = None,
    max_fee: Optional[int] = None,
    min_rating: float = 3.0,
    limit: int = 20,
    offset: int = 0,
    db=Depends(get_db),
    current_user=Depends(get_current_user),
):
    """Browse verified agents. Filterable by location, specialization, language, fee."""
    where_parts = ["a.is_verified = true", "a.is_active = true"]
    params: dict = {"limit": limit, "offset": offset, "min_rating": min_rating}

    if district:
        where_parts.append("a.districts_covered @> ARRAY[:district]::varchar[]")
        params["district"] = district
    if specialization:
        where_parts.append("a.specializations @> ARRAY[:spec]::varchar[]")
        params["spec"] = specialization
    if language:
        where_parts.append("a.languages @> ARRAY[:lang]::varchar[]")
        params["lang"] = language
    if max_fee:
        where_parts.append("a.fee_per_session <= :max_fee")
        params["max_fee"] = max_fee

    where_parts.append("COALESCE(a.average_rating, 0) >= :min_rating")
    where = "WHERE " + " AND ".join(where_parts)

    result = await db.execute(
        text(f"""
            SELECT
                a.id, a.full_name, a.profile_photo_url, a.bio,
                a.specializations, a.languages, a.districts_covered,
                a.fee_per_session, a.average_rating, a.total_reviews,
                a.total_sessions, a.is_online, a.response_time_minutes,
                a.available_session_types
            FROM agents a
            {where}
            ORDER BY a.average_rating DESC NULLS LAST, a.total_sessions DESC
            LIMIT :limit OFFSET :offset
        """),
        params,
    )
    agents = result.fetchall()

    count_r = await db.execute(
        text(f"SELECT COUNT(*) FROM agents a {where}"),
        {k: v for k, v in params.items() if k not in ("limit", "offset")},
    )

    return {
        "agents": [dict(a._mapping) for a in agents],
        "total": count_r.scalar() or 0,
        "limit": limit,
        "offset": offset,
    }


@app.get("/api/v1/agents/{agent_id}")
async def get_agent_profile(
    agent_id: str,
    db=Depends(get_db),
    current_user=Depends(get_current_user),
):
    result = await db.execute(
        text("""
            SELECT a.*,
                (SELECT COUNT(*) FROM agent_sessions s WHERE s.agent_id = a.id AND s.status = 'completed') as completed_sessions
            FROM agents a
            WHERE a.id = :id AND a.is_active = true
        """),
        {"id": agent_id},
    )
    row = result.fetchone()
    if not row:
        raise HTTPException(404, "Agent not found")

    # Recent reviews
    reviews_r = await db.execute(
        text("""
            SELECT ar.rating, ar.review, ar.tags, ar.created_at, u.full_name as reviewer_name
            FROM agent_reviews ar
            JOIN users u ON ar.student_id = u.id
            WHERE ar.agent_id = :agent_id
            ORDER BY ar.created_at DESC
            LIMIT 5
        """),
        {"agent_id": agent_id},
    )
    reviews = reviews_r.fetchall()

    data = dict(row._mapping)
    data["recent_reviews"] = [dict(r._mapping) for r in reviews]
    return data


@app.post("/api/v1/agents/sessions/book")
async def book_session(
    body: BookSessionRequest,
    db=Depends(get_db),
    current_user=Depends(get_current_user),
):
    """Book a session with a human agent."""
    agent_r = await db.execute(
        text(
            "SELECT id, full_name, fee_per_session FROM agents WHERE id = :id AND is_active = true AND is_verified = true"
        ),
        {"id": body.agent_id},
    )
    agent = agent_r.fetchone()
    if not agent:
        raise HTTPException(404, "Agent not found or unavailable")

    if body.scheduled_at < datetime.utcnow():
        raise HTTPException(400, "Cannot book a session in the past")

    session_id = uuid.uuid4()
    total_fee = agent.fee_per_session * (body.duration_minutes // 30)

    await db.execute(
        text("""
            INSERT INTO agent_sessions
                (id, student_id, agent_id, session_type, scheduled_at, duration_minutes,
                 issue_description, documents_needed, preferred_language,
                 fee_amount, status, created_at)
            VALUES
                (:id, :student_id, :agent_id, :session_type, :scheduled_at, :duration,
                 :issue, :docs::jsonb, :lang, :fee, 'pending', NOW())
        """),
        {
            "id": session_id,
            "student_id": current_user.user_id,
            "agent_id": body.agent_id,
            "session_type": body.session_type,
            "scheduled_at": body.scheduled_at,
            "duration": body.duration_minutes,
            "issue": body.issue_description,
            "docs": str(body.documents_needed).replace("'", '"'),
            "lang": body.preferred_language,
            "fee": total_fee,
        },
    )
    await db.commit()

    logger.info(
        f"Session {session_id} booked: student {current_user.user_id} → agent {body.agent_id}"
    )
    return {
        "session_id": str(session_id),
        "agent_name": agent.full_name,
        "scheduled_at": body.scheduled_at.isoformat(),
        "duration_minutes": body.duration_minutes,
        "fee_amount": total_fee,
        "status": "pending",
        "message": f"Session booked with {agent.full_name}. They will confirm within 30 minutes.",
    }


@app.get("/api/v1/agents/sessions/my")
async def my_sessions(
    status: Optional[str] = None,
    db=Depends(get_db),
    current_user=Depends(get_current_user),
):
    where = "WHERE s.student_id = :uid"
    params: dict = {"uid": current_user.user_id}
    if status:
        where += " AND s.status = :status"
        params["status"] = status

    result = await db.execute(
        text(f"""
            SELECT
                s.id, s.session_type, s.scheduled_at, s.duration_minutes,
                s.issue_description, s.fee_amount, s.status, s.meeting_link,
                s.notes, s.created_at,
                a.id as agent_id, a.full_name as agent_name,
                a.profile_photo_url, a.phone as agent_phone
            FROM agent_sessions s
            JOIN agents a ON s.agent_id = a.id
            {where}
            ORDER BY s.scheduled_at DESC
        """),
        params,
    )
    sessions = result.fetchall()
    return {"sessions": [dict(s._mapping) for s in sessions], "total": len(sessions)}


@app.post("/api/v1/agents/sessions/{session_id}/rate")
async def rate_session(
    session_id: str,
    body: RateAgentRequest,
    db=Depends(get_db),
    current_user=Depends(get_current_user),
):
    session_r = await db.execute(
        text(
            "SELECT agent_id FROM agent_sessions WHERE id = :id AND student_id = :uid AND status = 'completed'"
        ),
        {"id": session_id, "uid": current_user.user_id},
    )
    session = session_r.fetchone()
    if not session:
        raise HTTPException(404, "Session not found or not completed")

    existing = await db.execute(
        text("SELECT id FROM agent_reviews WHERE session_id = :sid"),
        {"sid": session_id},
    )
    if existing.fetchone():
        raise HTTPException(409, "Already rated this session")

    review_id = uuid.uuid4()
    await db.execute(
        text("""
            INSERT INTO agent_reviews (id, session_id, agent_id, student_id, rating, review, tags, created_at)
            VALUES (:id, :sid, :agent_id, :student_id, :rating, :review, :tags::jsonb, NOW())
        """),
        {
            "id": review_id,
            "sid": session_id,
            "agent_id": session.agent_id,
            "student_id": current_user.user_id,
            "rating": body.rating,
            "review": body.review,
            "tags": str(body.tags).replace("'", '"'),
        },
    )

    # Update agent's average rating
    await db.execute(
        text("""
            UPDATE agents SET
                average_rating = (
                    SELECT AVG(rating) FROM agent_reviews WHERE agent_id = :agent_id
                ),
                total_reviews = (
                    SELECT COUNT(*) FROM agent_reviews WHERE agent_id = :agent_id
                )
            WHERE id = :agent_id
        """),
        {"agent_id": session.agent_id},
    )
    await db.commit()
    return {"success": True, "review_id": str(review_id)}


@app.get("/api/v1/agents/specializations")
async def list_specializations():
    return {
        "specializations": [
            {"id": "nsp", "label": "NSP / National Scholarship"},
            {"id": "up_scholarship", "label": "UP Scholarship Portal"},
            {"id": "govt_job", "label": "Government Job Applications"},
            {"id": "ssc", "label": "SSC / Railway Exams"},
            {"id": "pfms", "label": "PFMS Payment Issues"},
            {
                "id": "document_renewal",
                "label": "Document Renewal (Income/Caste/Domicile)",
            },
            {"id": "college_admission", "label": "College Admission Forms"},
            {"id": "bank_account", "label": "Bank Account / PM Jan Dhan"},
            {"id": "aadhaar", "label": "Aadhaar Update / Correction"},
        ]
    }
