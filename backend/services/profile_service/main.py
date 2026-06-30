"""
FillFormAI - Profile Service (port 8002)
Handles: User profile, Career DNA builder, education, family, documents vault metadata
"""

import logging
import uuid
from datetime import date
from typing import Optional

from fastapi import FastAPI, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from sqlalchemy import text

from backend.shared.config.settings import settings
from backend.shared.database import get_db
from backend.shared.middleware.auth import get_current_user

logger = logging.getLogger(__name__)

app = FastAPI(title="FillFormAI - Profile Service", version="1.0.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ── Models ─────────────────────────────────────────────────────────────────────


class EducationInfo(BaseModel):
    education_level: str = Field(..., description="10th|12th|diploma|ug|pg|phd")
    institution_name: Optional[str] = None
    board_or_university: Optional[str] = None
    marks_10th_percent: Optional[float] = None
    marks_12th_percent: Optional[float] = None
    current_year_of_study: Optional[int] = None
    stream: Optional[str] = None  # science|arts|commerce
    course_name: Optional[str] = None
    passing_year: Optional[int] = None


class FamilyInfo(BaseModel):
    father_name: Optional[str] = None
    father_occupation: Optional[str] = None
    mother_name: Optional[str] = None
    mother_occupation: Optional[str] = None
    family_income_annual: Optional[int] = None
    number_of_siblings: Optional[int] = None
    is_bpl: bool = False
    ration_card_type: Optional[str] = None  # bpl|apl|antyodaya


class ProfileUpdateRequest(BaseModel):
    full_name: Optional[str] = None
    dob: Optional[date] = None
    gender: Optional[str] = None
    phone: Optional[str] = None
    state: Optional[str] = None
    district: Optional[str] = None
    pincode: Optional[str] = None
    category: Optional[str] = None  # general|obc|sc|st|ews
    religion: Optional[str] = None
    disability_type: Optional[str] = None
    is_minority: bool = False
    education: Optional[EducationInfo] = None
    family: Optional[FamilyInfo] = None
    career_goal: Optional[str] = None
    skills: Optional[list[str]] = None
    languages_known: Optional[list[str]] = None
    whatsapp_opted_in: bool = True
    preferred_language: str = "hi"


class DocumentRecord(BaseModel):
    document_type: str
    file_name: str
    s3_key: str
    expires_at: Optional[date] = None
    is_verified: bool = False


# ── Helpers ────────────────────────────────────────────────────────────────────


def _compute_profile_completeness(row) -> float:
    """Returns 0.0–1.0 completeness score."""
    fields = [
        row.full_name,
        row.dob,
        row.gender,
        row.phone,
        row.state,
        row.district,
        row.category,
        row.education_level,
        row.family_income_annual,
        row.career_goal,
    ]
    filled = sum(1 for f in fields if f is not None)
    return round(filled / len(fields), 2)


def _build_career_dna(row) -> dict:
    return {
        "user_id": str(row.id),
        "full_name": row.full_name,
        "dob": str(row.dob) if row.dob else None,
        "gender": row.gender,
        "state": row.state,
        "district": row.district,
        "category": row.category,
        "religion": row.religion,
        "disability_type": row.disability_type,
        "is_minority": row.is_minority,
        "education_level": row.education_level,
        "marks_10th_percent": row.marks_10th_percent,
        "marks_12th_percent": row.marks_12th_percent,
        "stream": row.stream,
        "course_name": row.course_name,
        "institution_name": row.institution_name,
        "current_year_of_study": row.current_year_of_study,
        "family_income_annual": row.family_income_annual,
        "father_occupation": row.father_occupation,
        "is_bpl": row.is_bpl,
        "career_goal": row.career_goal,
        "skills": row.skills or [],
        "languages_known": row.languages_known or ["Hindi"],
        "preferred_language": row.preferred_language,
        "whatsapp_opted_in": row.whatsapp_opted_in,
    }


# ── Endpoints ──────────────────────────────────────────────────────────────────


@app.get("/health")
async def health():
    return {"status": "ok", "service": "profile-service"}


@app.get("/api/v1/profile/me")
async def get_my_profile(
    db=Depends(get_db),
    current_user=Depends(get_current_user),
):
    result = await db.execute(
        text("SELECT * FROM users WHERE id = :id"),
        {"id": current_user.user_id},
    )
    row = result.fetchone()
    if not row:
        raise HTTPException(404, "Profile not found")

    completeness = _compute_profile_completeness(row)
    return {
        "profile": dict(row._mapping),
        "career_dna": _build_career_dna(row),
        "completeness": completeness,
        "missing_fields": _get_missing_fields(row),
    }


@app.put("/api/v1/profile/me")
async def update_profile(
    body: ProfileUpdateRequest,
    db=Depends(get_db),
    current_user=Depends(get_current_user),
):
    updates = {}
    if body.full_name is not None:
        updates["full_name"] = body.full_name
    if body.dob is not None:
        updates["dob"] = body.dob
    if body.gender is not None:
        updates["gender"] = body.gender
    if body.phone is not None:
        updates["phone"] = body.phone
    if body.state is not None:
        updates["state"] = body.state
    if body.district is not None:
        updates["district"] = body.district
    if body.pincode is not None:
        updates["pincode"] = body.pincode
    if body.category is not None:
        updates["category"] = body.category
    if body.religion is not None:
        updates["religion"] = body.religion
    if body.disability_type is not None:
        updates["disability_type"] = body.disability_type
    if body.career_goal is not None:
        updates["career_goal"] = body.career_goal
    if body.skills is not None:
        updates["skills"] = body.skills
    if body.languages_known is not None:
        updates["languages_known"] = body.languages_known
    updates["whatsapp_opted_in"] = body.whatsapp_opted_in
    updates["preferred_language"] = body.preferred_language
    updates["is_minority"] = body.is_minority

    if body.education:
        edu = body.education
        if edu.education_level:
            updates["education_level"] = edu.education_level
        if edu.institution_name:
            updates["institution_name"] = edu.institution_name
        if edu.marks_10th_percent is not None:
            updates["marks_10th_percent"] = edu.marks_10th_percent
        if edu.marks_12th_percent is not None:
            updates["marks_12th_percent"] = edu.marks_12th_percent
        if edu.stream:
            updates["stream"] = edu.stream
        if edu.course_name:
            updates["course_name"] = edu.course_name
        if edu.current_year_of_study:
            updates["current_year_of_study"] = edu.current_year_of_study
        if edu.passing_year:
            updates["passing_year"] = edu.passing_year

    if body.family:
        fam = body.family
        if fam.father_name:
            updates["father_name"] = fam.father_name
        if fam.father_occupation:
            updates["father_occupation"] = fam.father_occupation
        if fam.mother_name:
            updates["mother_name"] = fam.mother_name
        if fam.family_income_annual is not None:
            updates["family_income_annual"] = fam.family_income_annual
        if fam.number_of_siblings is not None:
            updates["number_of_siblings"] = fam.number_of_siblings
        updates["is_bpl"] = fam.is_bpl
        if fam.ration_card_type:
            updates["ration_card_type"] = fam.ration_card_type

    if not updates:
        raise HTTPException(400, "No fields to update")

    set_clause = ", ".join(f"{k} = :{k}" for k in updates)
    updates["id"] = current_user.user_id
    updates["updated_at"] = "NOW()"

    await db.execute(
        text(f"UPDATE users SET {set_clause}, updated_at = NOW() WHERE id = :id"),
        updates,
    )
    await db.commit()

    return {"success": True, "message": "Profile updated"}


@app.get("/api/v1/profile/career-dna")
async def get_career_dna(
    db=Depends(get_db),
    current_user=Depends(get_current_user),
):
    """Returns the structured Career DNA used by AI engines."""
    result = await db.execute(
        text("SELECT * FROM users WHERE id = :id"),
        {"id": current_user.user_id},
    )
    row = result.fetchone()
    if not row:
        raise HTTPException(404, "User not found")
    return _build_career_dna(row)


@app.get("/api/v1/profile/documents")
async def list_documents(
    db=Depends(get_db),
    current_user=Depends(get_current_user),
):
    result = await db.execute(
        text("""
            SELECT id, document_type, file_name, s3_key, expires_at,
                   is_verified, is_expired, uploaded_at, created_at
            FROM documents
            WHERE user_id = :uid
            ORDER BY created_at DESC
        """),
        {"uid": current_user.user_id},
    )
    docs = result.fetchall()
    return {
        "documents": [dict(d._mapping) for d in docs],
        "total": len(docs),
    }


@app.post("/api/v1/profile/documents")
async def add_document(
    body: DocumentRecord,
    db=Depends(get_db),
    current_user=Depends(get_current_user),
):
    doc_id = uuid.uuid4()
    await db.execute(
        text("""
            INSERT INTO documents (id, user_id, document_type, file_name, s3_key, expires_at, is_verified, uploaded_at, created_at)
            VALUES (:id, :uid, :doc_type, :file_name, :s3_key, :expires_at, false, NOW(), NOW())
        """),
        {
            "id": doc_id,
            "uid": current_user.user_id,
            "doc_type": body.document_type,
            "file_name": body.file_name,
            "s3_key": body.s3_key,
            "expires_at": body.expires_at,
        },
    )
    await db.commit()
    return {"id": str(doc_id), "success": True}


@app.delete("/api/v1/profile/documents/{doc_id}")
async def delete_document(
    doc_id: str,
    db=Depends(get_db),
    current_user=Depends(get_current_user),
):
    result = await db.execute(
        text("DELETE FROM documents WHERE id = :id AND user_id = :uid RETURNING id"),
        {"id": doc_id, "uid": current_user.user_id},
    )
    if not result.fetchone():
        raise HTTPException(404, "Document not found")
    await db.commit()
    return {"success": True}


@app.get("/api/v1/profile/stats")
async def get_profile_stats(
    db=Depends(get_db),
    current_user=Depends(get_current_user),
):
    uid = current_user.user_id
    apps_r = await db.execute(
        text(
            "SELECT COUNT(*) as total, SUM(CASE WHEN status='approved' THEN 1 ELSE 0 END) as approved FROM applications WHERE user_id=:uid"
        ),
        {"uid": uid},
    )
    apps = apps_r.fetchone()

    docs_r = await db.execute(
        text(
            "SELECT COUNT(*) as total FROM documents WHERE user_id=:uid AND is_expired=false"
        ),
        {"uid": uid},
    )
    docs = docs_r.fetchone()

    return {
        "total_applications": apps.total or 0,
        "approved_applications": apps.approved or 0,
        "active_documents": docs.total or 0,
    }


def _get_missing_fields(row) -> list[str]:
    missing = []
    field_labels = {
        "full_name": "Full Name",
        "dob": "Date of Birth",
        "gender": "Gender",
        "state": "State",
        "district": "District",
        "category": "Category (General/OBC/SC/ST)",
        "education_level": "Education Level",
        "marks_12th_percent": "12th Marks %",
        "family_income_annual": "Annual Family Income",
        "career_goal": "Career Goal",
    }
    for field, label in field_labels.items():
        if getattr(row, field, None) is None:
            missing.append(label)
    return missing
