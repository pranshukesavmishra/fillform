"""
FillFormAI - Opportunity Service
Handles: Opportunity CRUD, Search, Eligibility Filter, Recommendations, Scraping
"""

import logging
from datetime import date
from typing import Optional
import uuid

from fastapi import FastAPI, Depends, HTTPException, Query, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field, field_validator
from sqlalchemy import select, and_, or_, func
from sqlalchemy.ext.asyncio import AsyncSession

from backend.shared.config.settings import settings
from backend.shared.database import get_db, init_db, close_db
from backend.shared.middleware.auth import get_current_user, get_current_admin
from backend.services.opportunity_service.models import (
    Opportunity,
    OpportunityView,
    OpportunitySave,
    OpportunityCategory,
    OpportunityStatus,
)

logger = logging.getLogger(__name__)

app = FastAPI(title="FillFormAI - Opportunity Service", version="1.0.0")
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


@app.on_event("shutdown")
async def shutdown():
    await close_db()


# ── Schemas ───────────────────────────────────────────────────────────────────
class OpportunityResponse(BaseModel):
    id: str
    title: str
    short_description: Optional[str]
    category: str
    subcategory: Optional[str]
    issuing_authority: Optional[str]
    portal_url: Optional[str]
    deadline: Optional[date]
    amount_min: Optional[float]
    amount_max: Optional[float]
    currency: str
    status: str
    is_verified: bool
    verification_confidence: float
    eligibility_rules: dict
    documents_required: list
    difficulty_score: float
    competition_score: float
    platform_applicants: int
    tags: list
    source: Optional[str]

    class Config:
        from_attributes = True

    @field_validator("id", mode="before")
    @classmethod
    def _coerce_id(cls, v):
        return str(v)


class EligibilityCheckRequest(BaseModel):
    career_dna: dict = Field(..., description="Student's career DNA object")
    opportunity_ids: Optional[list[str]] = None  # If None, check all active


class EligibilityResult(BaseModel):
    opportunity_id: str
    is_eligible: bool
    confidence: float
    matching_criteria: list[str]
    failing_criteria: list[str]
    borderline_criteria: list[str]
    missing_data: list[str]
    success_probability: Optional[float]


class OpportunityCreateRequest(BaseModel):
    title: str
    category: OpportunityCategory
    short_description: Optional[str] = None
    full_description: Optional[str] = None
    subcategory: Optional[str] = None
    issuing_authority: Optional[str] = None
    portal_url: Optional[str] = None
    deadline: Optional[date] = None
    amount_min: Optional[float] = None
    amount_max: Optional[float] = None
    eligibility_rules: dict = {}
    documents_required: list = []
    tags: list = []


# ── Health ────────────────────────────────────────────────────────────────────
@app.get("/health")
async def health():
    return {"status": "healthy", "service": "opportunity"}


# ── List & Search ─────────────────────────────────────────────────────────────
@app.get("/api/v1/opportunities", response_model=dict)
async def list_opportunities(
    q: Optional[str] = Query(None, description="Full-text search"),
    category: Optional[OpportunityCategory] = None,
    state: Optional[str] = None,
    min_amount: Optional[float] = None,
    max_amount: Optional[float] = None,
    deadline_after: Optional[date] = None,
    deadline_before: Optional[date] = None,
    education_level: Optional[str] = None,
    is_verified: Optional[bool] = None,
    tags: Optional[str] = Query(None, description="Comma-separated tags"),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    sort_by: str = Query(
        "deadline", pattern="^(deadline|amount|created_at|difficulty_score)$"
    ),
    sort_dir: str = Query("asc", pattern="^(asc|desc)$"),
    db: AsyncSession = Depends(get_db),
):
    query = select(Opportunity).where(
        Opportunity.status.in_([OpportunityStatus.ACTIVE, OpportunityStatus.UPCOMING])
    )

    if q:
        query = query.where(
            or_(
                func.to_tsvector("english", Opportunity.title).op("@@")(
                    func.plainto_tsquery("english", q)
                ),
                Opportunity.title.ilike(f"%{q}%"),
                Opportunity.short_description.ilike(f"%{q}%"),
            )
        )

    if category:
        query = query.where(Opportunity.category == category)
    if min_amount is not None:
        query = query.where(Opportunity.amount_min >= min_amount)
    if max_amount is not None:
        query = query.where(Opportunity.amount_max <= max_amount)
    if deadline_after:
        query = query.where(Opportunity.deadline >= deadline_after)
    if deadline_before:
        query = query.where(Opportunity.deadline <= deadline_before)
    if is_verified is not None:
        query = query.where(Opportunity.is_verified == is_verified)
    if education_level:
        query = query.where(
            Opportunity.eligibility_rules["education_level_min"].astext
            == education_level
        )
    if state:
        query = query.where(
            or_(
                Opportunity.eligibility_rules["states_allowed"].contains([state]),
                Opportunity.eligibility_rules["states_allowed"].contains(["ALL"]),
            )
        )
    if tags:
        tag_list = [t.strip() for t in tags.split(",")]
        query = query.where(Opportunity.tags.contains(tag_list))

    # Count
    count_result = await db.scalar(select(func.count()).select_from(query.subquery()))

    # Sort
    sort_col = getattr(Opportunity, sort_by, Opportunity.deadline)
    query = query.order_by(sort_col.asc() if sort_dir == "asc" else sort_col.desc())

    # Paginate
    query = query.offset((page - 1) * page_size).limit(page_size)
    result = await db.execute(query)
    opportunities = result.scalars().all()

    return {
        "data": [OpportunityResponse.model_validate(o) for o in opportunities],
        "total": count_result or 0,
        "page": page,
        "page_size": page_size,
        "total_pages": ((count_result or 0) + page_size - 1) // page_size,
    }


@app.get("/api/v1/opportunities/{opportunity_id}", response_model=OpportunityResponse)
async def get_opportunity(
    opportunity_id: str,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    background_tasks: BackgroundTasks = BackgroundTasks(),
):
    try:
        opp_uuid = uuid.UUID(opportunity_id)
    except ValueError:
        raise HTTPException(status_code=404, detail="Opportunity not found")

    opportunity = await db.get(Opportunity, opp_uuid)
    if not opportunity:
        raise HTTPException(status_code=404, detail="Opportunity not found")

    background_tasks.add_task(
        _record_view, db, opportunity_id, str(current_user.user_id)
    )
    return OpportunityResponse.model_validate(opportunity)


async def _record_view(db: AsyncSession, opp_id: str, user_id: str):
    try:
        db.add(
            OpportunityView(
                opportunity_id=uuid.UUID(opp_id),
                user_id=uuid.UUID(user_id),
            )
        )
        opp = await db.get(Opportunity, uuid.UUID(opp_id))
        if opp:
            opp.platform_applicants = opp.platform_applicants or 0
        await db.commit()
    except Exception:
        pass


# ── Eligibility Check ─────────────────────────────────────────────────────────
@app.post(
    "/api/v1/opportunities/check-eligibility", response_model=list[EligibilityResult]
)
async def check_eligibility(
    body: EligibilityCheckRequest,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Fast eligibility check against structured rules.
    AI-enhanced eligibility uses the AI service for complex cases.
    """
    query = select(Opportunity).where(Opportunity.status == OpportunityStatus.ACTIVE)
    if body.opportunity_ids:
        ids = [uuid.UUID(i) for i in body.opportunity_ids]
        query = query.where(Opportunity.id.in_(ids))

    result = await db.execute(query)
    opportunities = result.scalars().all()

    results = []
    for opp in opportunities:
        eligibility = _evaluate_eligibility(body.career_dna, opp)
        results.append(eligibility)

    # Sort: eligible first, then by confidence
    results.sort(key=lambda r: (not r.is_eligible, -r.confidence))
    return results


def _evaluate_eligibility(career_dna: dict, opp: Opportunity) -> EligibilityResult:
    rules = opp.eligibility_rules or {}
    matching = []
    failing = []
    borderline = []
    missing = []

    def check(field: str, condition: bool, label: str, is_borderline: bool = False):
        if field not in career_dna or career_dna.get(field) is None:
            missing.append(label)
        elif condition:
            (borderline if is_borderline else matching).append(label)
        else:
            failing.append(label)

    # Education check
    edu_levels = [
        "5th",
        "8th",
        "10th",
        "10+2",
        "Diploma",
        "Graduate",
        "Postgraduate",
        "PhD",
    ]
    student_edu = career_dna.get("education_level", "")
    required_edu = rules.get("education_level_min", "")
    if required_edu and student_edu:
        student_idx = edu_levels.index(student_edu) if student_edu in edu_levels else -1
        req_idx = edu_levels.index(required_edu) if required_edu in edu_levels else -1
        check("education_level", student_idx >= req_idx, f"Education: {required_edu}+")

    # Marks check
    student_marks = career_dna.get("marks_percent")
    req_marks = rules.get("marks_min_percent")
    if req_marks is not None and student_marks is not None:
        is_borderline = req_marks - student_marks <= 5 and student_marks < req_marks
        check(
            "marks_percent",
            student_marks >= req_marks,
            f"Marks ≥ {req_marks}%",
            is_borderline,
        )

    # Category
    categories = rules.get("categories", [])
    if categories:
        student_category = career_dna.get("category")
        if not student_category:
            missing.append("Category (SC/ST/OBC/General)")
        elif student_category in categories or "General" in categories:
            matching.append(f"Category: {student_category}")
        else:
            failing.append(f"Category: {student_category} (need {categories})")

    # Income
    income_ceiling = rules.get("income_ceiling_annual")
    student_income = career_dna.get("family_income_annual")
    if income_ceiling and student_income is not None:
        is_borderline = (
            student_income > income_ceiling and student_income <= income_ceiling * 1.05
        )
        check(
            "family_income_annual",
            student_income <= income_ceiling,
            f"Income ≤ ₹{income_ceiling:,}",
            is_borderline,
        )

    # Age
    age_min = rules.get("age_min")
    age_max = rules.get("age_max")
    student_age = career_dna.get("age")
    if student_age is not None:
        if age_min and age_max:
            check(
                "age",
                age_min <= student_age <= age_max,
                f"Age {age_min}-{age_max} years",
            )
        elif age_min:
            check("age", student_age >= age_min, f"Age ≥ {age_min} years")
        elif age_max:
            check("age", student_age <= age_max, f"Age ≤ {age_max} years")

    # State
    states = rules.get("states_allowed", [])
    if states and "ALL" not in states:
        student_state = career_dna.get("state")
        if not student_state:
            missing.append("State")
        elif student_state in states:
            matching.append(f"State: {student_state}")
        else:
            failing.append(f"State: {student_state} not in eligible states")

    is_eligible = len(failing) == 0 and len(missing) == 0
    confidence = (
        0.95 if (not missing and not borderline) else 0.7 if not failing else 0.3
    )

    return EligibilityResult(
        opportunity_id=str(opp.id),
        is_eligible=is_eligible,
        confidence=confidence,
        matching_criteria=matching,
        failing_criteria=failing,
        borderline_criteria=borderline,
        missing_data=missing,
        success_probability=None,  # Computed by AI service
    )


# ── Save/Unsave ───────────────────────────────────────────────────────────────
@app.post("/api/v1/opportunities/{opportunity_id}/save")
async def save_opportunity(
    opportunity_id: str,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    try:
        opp_uuid = uuid.UUID(opportunity_id)
    except ValueError:
        raise HTTPException(status_code=404, detail="Opportunity not found")

    existing = await db.scalar(
        select(OpportunitySave).where(
            and_(
                OpportunitySave.opportunity_id == opp_uuid,
                OpportunitySave.user_id == current_user.user_id,
            )
        )
    )
    if existing:
        await db.delete(existing)
        await db.commit()
        return {"saved": False}

    db.add(
        OpportunitySave(
            opportunity_id=opp_uuid,
            user_id=current_user.user_id,
        )
    )
    await db.commit()
    return {"saved": True}


# ── Admin: Create Opportunity ─────────────────────────────────────────────────
@app.post("/api/v1/admin/opportunities", response_model=OpportunityResponse)
async def create_opportunity(
    body: OpportunityCreateRequest,
    current_user=Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    opp = Opportunity(**body.model_dump())
    db.add(opp)
    await db.commit()
    await db.refresh(opp)
    return OpportunityResponse.model_validate(opp)


# ── Stats ─────────────────────────────────────────────────────────────────────
@app.get("/api/v1/opportunities/stats/summary")
async def opportunity_stats(db: AsyncSession = Depends(get_db)):
    total = await db.scalar(select(func.count(Opportunity.id)))
    active = await db.scalar(
        select(func.count(Opportunity.id)).where(
            Opportunity.status == OpportunityStatus.ACTIVE
        )
    )
    by_category = await db.execute(
        select(Opportunity.category, func.count(Opportunity.id))
        .where(Opportunity.status == OpportunityStatus.ACTIVE)
        .group_by(Opportunity.category)
    )
    return {
        "total": total,
        "active": active,
        "by_category": dict(by_category.all()),
    }
