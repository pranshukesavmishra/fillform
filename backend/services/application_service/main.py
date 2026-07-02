"""
FillFormAI - Application Service (port 8004)
Handles: Apply to opportunities, track status, AI form fill, document attachment
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

app = FastAPI(title="FillFormAI - Application Service", version="1.0.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Application status flow:
# draft → submitted → under_review → approved | rejected | on_hold
APPLICATION_STATUSES = [
    "draft",
    "submitted",
    "under_review",
    "approved",
    "rejected",
    "on_hold",
    "withdrawn",
]


# ── Models ─────────────────────────────────────────────────────────────────────


class ApplyRequest(BaseModel):
    opportunity_id: str
    form_data: dict = Field(default_factory=dict)
    documents: list[str] = Field(
        default_factory=list, description="List of document IDs to attach"
    )
    registration_number: Optional[str] = None
    notes: Optional[str] = None


class UpdateApplicationRequest(BaseModel):
    form_data: Optional[dict] = None
    status: Optional[str] = None
    registration_number: Optional[str] = None
    notes: Optional[str] = None
    rejection_reason: Optional[str] = None


class StatusCheckRequest(BaseModel):
    registration_number: str
    portal: str = "NSP"


# ── Endpoints ──────────────────────────────────────────────────────────────────


@app.get("/health")
async def health():
    return {"status": "ok", "service": "application-service"}


@app.post("/api/v1/applications/apply")
async def apply_to_opportunity(
    body: ApplyRequest,
    db=Depends(get_db),
    current_user=Depends(get_current_user),
):
    """Submit a new application for an opportunity."""
    # Check opportunity exists
    opp = await db.execute(
        text(
            "SELECT id, title, deadline, max_applications FROM opportunities WHERE id = :id AND is_active = true"
        ),
        {"id": body.opportunity_id},
    )
    opp_row = opp.fetchone()
    if not opp_row:
        raise HTTPException(404, "Opportunity not found or closed")

    if opp_row.deadline and opp_row.deadline < datetime.utcnow().date():
        raise HTTPException(400, "Application deadline has passed")

    # Check duplicate application
    existing = await db.execute(
        text(
            "SELECT id FROM applications WHERE user_id = :uid AND opportunity_id = :oid AND status != 'withdrawn'"
        ),
        {"uid": current_user.user_id, "oid": body.opportunity_id},
    )
    if existing.fetchone():
        raise HTTPException(409, "You have already applied to this opportunity")

    app_id = uuid.uuid4()
    now = datetime.utcnow()

    await db.execute(
        text("""
            INSERT INTO applications
                (id, user_id, opportunity_id, status, form_data, registration_number,
                 notes, submitted_at, created_at, updated_at)
            VALUES
                (:id, :uid, :oid, 'submitted', :form_data::jsonb, :reg_num,
                 :notes, NOW(), NOW(), NOW())
        """),
        {
            "id": app_id,
            "uid": current_user.user_id,
            "oid": body.opportunity_id,
            "form_data": str(body.form_data).replace("'", '"'),
            "reg_num": body.registration_number,
            "notes": body.notes,
        },
    )

    # Attach documents
    for doc_id in body.documents:
        await db.execute(
            text("""
                INSERT INTO application_documents (application_id, document_id, attached_at)
                VALUES (:app_id, :doc_id, NOW())
                ON CONFLICT DO NOTHING
            """),
            {"app_id": app_id, "doc_id": doc_id},
        )

    await db.commit()
    logger.info(
        f"Application {app_id} submitted by user {current_user.user_id} for {body.opportunity_id}"
    )

    return {
        "application_id": str(app_id),
        "status": "submitted",
        "opportunity": opp_row.title,
        "submitted_at": now.isoformat(),
        "message": "Application submitted successfully",
    }


@app.get("/api/v1/applications/my")
async def list_my_applications(
    status: Optional[str] = None,
    limit: int = 20,
    offset: int = 0,
    db=Depends(get_db),
    current_user=Depends(get_current_user),
):
    """List all applications for the current user."""
    where = "WHERE a.user_id = :uid"
    params: dict = {"uid": current_user.user_id, "limit": limit, "offset": offset}

    if status:
        where += " AND a.status = :status"
        params["status"] = status

    result = await db.execute(
        text(f"""
            SELECT
                a.id, a.status, a.registration_number, a.submitted_at,
                a.outcome_date, a.rejection_reason, a.notes,
                o.id as opp_id, o.title as opp_title, o.category as opp_category,
                o.amount as opp_amount, o.deadline as opp_deadline,
                o.issuing_authority
            FROM applications a
            JOIN opportunities o ON a.opportunity_id = o.id
            {where}
            ORDER BY a.created_at DESC
            LIMIT :limit OFFSET :offset
        """),
        params,
    )
    rows = result.fetchall()

    count_r = await db.execute(
        text(f"SELECT COUNT(*) FROM applications a {where}"),
        {k: v for k, v in params.items() if k not in ("limit", "offset")},
    )
    total = count_r.scalar()

    return {
        "applications": [
            {
                "id": str(r.id),
                "status": r.status,
                "registration_number": r.registration_number,
                "submitted_at": str(r.submitted_at) if r.submitted_at else None,
                "outcome_date": str(r.outcome_date) if r.outcome_date else None,
                "rejection_reason": r.rejection_reason,
                "notes": r.notes,
                "opportunity": {
                    "id": str(r.opp_id),
                    "title": r.opp_title,
                    "category": r.opp_category,
                    "amount": r.opp_amount,
                    "deadline": str(r.opp_deadline) if r.opp_deadline else None,
                    "issuing_authority": r.issuing_authority,
                },
            }
            for r in rows
        ],
        "total": total,
        "limit": limit,
        "offset": offset,
    }


@app.get("/api/v1/applications/{application_id}")
async def get_application(
    application_id: str,
    db=Depends(get_db),
    current_user=Depends(get_current_user),
):
    result = await db.execute(
        text("""
            SELECT a.*, o.title as opp_title, o.category, o.amount, o.issuing_authority
            FROM applications a
            JOIN opportunities o ON a.opportunity_id = o.id
            WHERE a.id = :id AND a.user_id = :uid
        """),
        {"id": application_id, "uid": current_user.user_id},
    )
    row = result.fetchone()
    if not row:
        raise HTTPException(404, "Application not found")

    # Get attached documents
    docs_r = await db.execute(
        text("""
            SELECT d.id, d.document_type, d.file_name, d.is_verified
            FROM application_documents ad
            JOIN documents d ON ad.document_id = d.id
            WHERE ad.application_id = :app_id
        """),
        {"app_id": application_id},
    )
    docs = docs_r.fetchall()

    data = dict(row._mapping)
    data["documents"] = [dict(d._mapping) for d in docs]
    data["opportunity_title"] = row.opp_title
    return data


@app.put("/api/v1/applications/{application_id}")
async def update_application(
    application_id: str,
    body: UpdateApplicationRequest,
    db=Depends(get_db),
    current_user=Depends(get_current_user),
):
    # Verify ownership
    existing = await db.execute(
        text("SELECT id, status FROM applications WHERE id = :id AND user_id = :uid"),
        {"id": application_id, "uid": current_user.user_id},
    )
    row = existing.fetchone()
    if not row:
        raise HTTPException(404, "Application not found")
    if row.status in ("approved", "rejected") and body.status not in ("withdrawn",):
        raise HTTPException(400, f"Cannot update a {row.status} application")

    updates = {}
    if body.form_data is not None:
        updates["form_data"] = str(body.form_data).replace("'", '"') + "::jsonb"
    if body.status is not None:
        if body.status not in APPLICATION_STATUSES:
            raise HTTPException(
                400, f"Invalid status. Choose from {APPLICATION_STATUSES}"
            )
        updates["status"] = body.status
        if body.status in ("approved", "rejected"):
            updates["outcome_date"] = "NOW()"
    if body.registration_number is not None:
        updates["registration_number"] = body.registration_number
    if body.notes is not None:
        updates["notes"] = body.notes
    if body.rejection_reason is not None:
        updates["rejection_reason"] = body.rejection_reason

    if not updates:
        raise HTTPException(400, "No fields to update")

    set_parts = []
    params: dict = {"id": application_id}
    for k, v in updates.items():
        if v == "NOW()":
            set_parts.append(f"{k} = NOW()")
        elif v.endswith("::jsonb"):
            set_parts.append(f"{k} = :{k}::jsonb")
            params[k] = v.replace("::jsonb", "")
        else:
            set_parts.append(f"{k} = :{k}")
            params[k] = v

    await db.execute(
        text(
            f"UPDATE applications SET {', '.join(set_parts)}, updated_at = NOW() WHERE id = :id"
        ),
        params,
    )
    await db.commit()
    return {"success": True, "application_id": application_id}


@app.delete("/api/v1/applications/{application_id}/withdraw")
async def withdraw_application(
    application_id: str,
    db=Depends(get_db),
    current_user=Depends(get_current_user),
):
    result = await db.execute(
        text("""
            UPDATE applications SET status = 'withdrawn', updated_at = NOW()
            WHERE id = :id AND user_id = :uid AND status NOT IN ('approved', 'rejected', 'withdrawn')
            RETURNING id
        """),
        {"id": application_id, "uid": current_user.user_id},
    )
    if not result.fetchone():
        raise HTTPException(400, "Cannot withdraw this application")
    await db.commit()
    return {"success": True, "message": "Application withdrawn"}


@app.get("/api/v1/applications/stats/summary")
async def application_stats(
    db=Depends(get_db),
    current_user=Depends(get_current_user),
):
    result = await db.execute(
        text("""
            SELECT
                COUNT(*) FILTER (WHERE status = 'submitted') as submitted,
                COUNT(*) FILTER (WHERE status = 'under_review') as under_review,
                COUNT(*) FILTER (WHERE status = 'approved') as approved,
                COUNT(*) FILTER (WHERE status = 'rejected') as rejected,
                COUNT(*) FILTER (WHERE status = 'draft') as draft,
                COUNT(*) as total
            FROM applications WHERE user_id = :uid
        """),
        {"uid": current_user.user_id},
    )
    row = result.fetchone()
    return dict(row._mapping) if row else {}


@app.post("/api/v1/applications/{application_id}/check-status")
async def check_portal_status(
    application_id: str,
    body: StatusCheckRequest,
    db=Depends(get_db),
    current_user=Depends(get_current_user),
):
    """
    Placeholder for portal status scraping.
    In production: scrapes NSP/UP Scholarship portals via Playwright.
    """
    existing = await db.execute(
        text(
            "SELECT id, registration_number FROM applications WHERE id = :id AND user_id = :uid"
        ),
        {"id": application_id, "uid": current_user.user_id},
    )
    row = existing.fetchone()
    if not row:
        raise HTTPException(404, "Application not found")

    return {
        "registration_number": body.registration_number or row.registration_number,
        "portal": body.portal,
        "status": "check_manually",
        "portal_url": _get_portal_url(body.portal, body.registration_number),
        "message": "Automated portal check coming soon. Please check the portal directly.",
    }


def _get_portal_url(portal: str, reg_num: Optional[str]) -> str:
    portals = {
        "NSP": "https://scholarships.gov.in/fresh/loginPage",
        "UP": "https://scholarship.up.gov.in/",
        "PFMS": "https://pfms.nic.in/",
        "SSC": "https://ssc.nic.in/",
    }
    return portals.get(portal.upper(), "https://scholarships.gov.in")
