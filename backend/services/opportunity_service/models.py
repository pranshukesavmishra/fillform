from sqlalchemy import String, Float, Boolean, Text, Integer, Date, Enum as SAEnum
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.dialects.postgresql import UUID, JSONB
from backend.shared.models.base import BaseModel
from enum import Enum
import uuid


class OpportunityCategory(str, Enum):
    SCHOLARSHIP = "scholarship"
    GOVERNMENT_JOB = "government_job"
    ADMISSION = "admission"
    FELLOWSHIP = "fellowship"
    INTERNSHIP = "internship"
    EXAM = "exam"
    SKILL_TRAINING = "skill_training"
    LOAN = "loan"


class OpportunityStatus(str, Enum):
    ACTIVE = "active"
    UPCOMING = "upcoming"
    CLOSED = "closed"
    DRAFT = "draft"


class Opportunity(BaseModel):
    __tablename__ = "opportunities"

    title: Mapped[str] = mapped_column(String(500), nullable=False, index=True)
    short_description: Mapped[str] = mapped_column(String(1000), nullable=True)
    full_description: Mapped[str] = mapped_column(Text, nullable=True)
    category: Mapped[str] = mapped_column(
        SAEnum(OpportunityCategory), nullable=False, index=True
    )
    subcategory: Mapped[str] = mapped_column(String(100), nullable=True)
    issuing_authority: Mapped[str] = mapped_column(String(255), nullable=True)
    portal_url: Mapped[str] = mapped_column(Text, nullable=True)
    application_url: Mapped[str] = mapped_column(Text, nullable=True)

    # Dates
    open_date: Mapped[Date] = mapped_column(Date, nullable=True)
    deadline: Mapped[Date] = mapped_column(Date, nullable=True, index=True)
    result_date: Mapped[Date] = mapped_column(Date, nullable=True)

    # Financial
    amount_min: Mapped[float] = mapped_column(Float, nullable=True)
    amount_max: Mapped[float] = mapped_column(Float, nullable=True)
    currency: Mapped[str] = mapped_column(String(3), default="INR")

    # Status
    status: Mapped[str] = mapped_column(
        SAEnum(OpportunityStatus),
        default=OpportunityStatus.ACTIVE,
        nullable=False,
        index=True,
    )
    is_verified: Mapped[bool] = mapped_column(Boolean, default=False)
    verification_confidence: Mapped[float] = mapped_column(Float, default=0.0)

    # Eligibility rules (structured JSON)
    eligibility_rules: Mapped[dict] = mapped_column(JSONB, default=dict)
    # Example:
    # {
    #   "education_level_min": "10+2",
    #   "streams_allowed": ["Science", "Commerce", "Arts"],
    #   "marks_min_percent": 60.0,
    #   "categories": ["SC", "ST", "OBC", "General"],
    #   "income_ceiling_annual": 800000,
    #   "age_min": 17,
    #   "age_max": 25,
    #   "states_allowed": ["UP", "Bihar", "ALL"],
    #   "gender": "any",
    #   "disability_required": false,
    #   "first_gen_college_required": false
    # }

    documents_required: Mapped[list] = mapped_column(JSONB, default=list)
    # ["aadhaar", "10th_marksheet", "income_certificate", ...]

    # AI scores
    difficulty_score: Mapped[float] = mapped_column(Float, default=0.5)  # 0-1
    competition_score: Mapped[float] = mapped_column(Float, default=0.5)  # 0-1

    # Analytics
    total_applicants: Mapped[int] = mapped_column(Integer, default=0)
    total_seats: Mapped[int] = mapped_column(Integer, nullable=True)
    platform_applicants: Mapped[int] = mapped_column(Integer, default=0)
    platform_success_count: Mapped[int] = mapped_column(Integer, default=0)

    # Metadata
    tags: Mapped[list] = mapped_column(JSONB, default=list)
    source: Mapped[str] = mapped_column(
        String(100), nullable=True
    )  # scraped | manual | api
    last_scraped_at: Mapped[str] = mapped_column(String(50), nullable=True)
    form_schema: Mapped[dict] = mapped_column(
        JSONB, default=dict
    )  # extracted form fields
    raw_content: Mapped[str] = mapped_column(Text, nullable=True)


class OpportunityView(BaseModel):
    __tablename__ = "opportunity_views"

    opportunity_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), nullable=False, index=True
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), nullable=False, index=True
    )
    source: Mapped[str] = mapped_column(
        String(50), nullable=True
    )  # search | recommendation | notification


class OpportunitySave(BaseModel):
    __tablename__ = "opportunity_saves"

    opportunity_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), nullable=False, index=True
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), nullable=False, index=True
    )
    notes: Mapped[str] = mapped_column(Text, nullable=True)
