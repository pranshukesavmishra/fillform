"""
FillFormAI - AI Service
Handles: Career Twin, Eligibility AI, Success Predictor, Form Fill Intelligence,
         Skill Gap Analysis, Roadmap Generation, SOP Builder
"""

import logging
from typing import Optional, AsyncGenerator
import json

from fastapi import FastAPI, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, Field

from backend.shared.config.settings import settings
from backend.services.ai_service.agents.career_twin import CareerTwinAgent
from backend.services.ai_service.engines.eligibility_engine import AIEligibilityEngine
from backend.services.ai_service.engines.success_predictor import SuccessPredictor
from backend.services.ai_service.engines.form_intelligence import FormIntelligenceEngine
from backend.services.ai_service.engines.skill_analyzer import SkillGapAnalyzer
from backend.services.ai_service.engines.roadmap_generator import RoadmapGenerator
from backend.services.ai_service.engines.sop_builder import SOPBuilder
from backend.services.ai_service.engines.appeal_writer import AppealWriter
from backend.services.ai_service.engines.web_form_filler import (
    auto_fill_government_form,
)
from backend.shared.middleware.auth import get_current_user

logger = logging.getLogger(__name__)

app = FastAPI(title="FillFormAI - AI Service", version="1.0.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Singleton engines
_career_twin: CareerTwinAgent | None = None
_eligibility_engine: AIEligibilityEngine | None = None
_success_predictor: SuccessPredictor | None = None
_form_engine: FormIntelligenceEngine | None = None
_skill_analyzer: SkillGapAnalyzer | None = None
_roadmap_gen: RoadmapGenerator | None = None
_sop_builder: SOPBuilder | None = None
_appeal_writer: AppealWriter | None = None


def get_career_twin() -> CareerTwinAgent:
    global _career_twin
    if _career_twin is None:
        _career_twin = CareerTwinAgent()
    return _career_twin


def get_form_engine() -> FormIntelligenceEngine:
    global _form_engine
    if _form_engine is None:
        _form_engine = FormIntelligenceEngine()
    return _form_engine


def get_eligibility_engine() -> AIEligibilityEngine:
    global _eligibility_engine
    if _eligibility_engine is None:
        _eligibility_engine = AIEligibilityEngine()
    return _eligibility_engine


@app.get("/health")
async def health():
    return {"status": "healthy", "service": "ai", "llm_provider": "anthropic+openai"}


# ── Career Twin Chat ──────────────────────────────────────────────────────────
class CareerTwinChatRequest(BaseModel):
    message: str = Field(..., min_length=1, max_length=2000)
    career_dna: dict = Field(..., description="Student's complete career DNA")
    conversation_id: Optional[str] = None
    language: str = Field(default="en", pattern="^(en|hi|ta|te|bn|mr|gu|kn)$")
    stream: bool = False


class CareerTwinResponse(BaseModel):
    reply: str
    conversation_id: str
    actions: list[dict] = []  # Suggested actions the UI can render as buttons
    opportunities: list[dict] = []  # Opportunities mentioned/recommended
    roadmap_steps: list[dict] = []
    confidence: float = 0.9


@app.post("/api/v1/ai/career-twin/chat")
async def career_twin_chat(
    body: CareerTwinChatRequest,
    current_user=Depends(get_current_user),
):
    agent = get_career_twin()

    if body.stream:

        async def event_stream() -> AsyncGenerator[str, None]:
            async for chunk in agent.stream_response(
                user_id=str(current_user.user_id),
                message=body.message,
                career_dna=body.career_dna,
                conversation_id=body.conversation_id,
                language=body.language,
            ):
                yield f"data: {json.dumps({'chunk': chunk})}\n\n"
            yield "data: [DONE]\n\n"

        return StreamingResponse(event_stream(), media_type="text/event-stream")

    response = await agent.chat(
        user_id=str(current_user.user_id),
        message=body.message,
        career_dna=body.career_dna,
        conversation_id=body.conversation_id,
        language=body.language,
    )
    return response


# ── Success Probability ────────────────────────────────────────────────────────
class SuccessProbabilityRequest(BaseModel):
    career_dna: dict
    opportunity_id: str
    opportunity_data: dict
    application_completeness: float = 1.0


class SuccessProbabilityResponse(BaseModel):
    probability: float  # 0-1
    confidence: float  # 0-1, based on sample size
    sample_size: int
    boosting_factors: list[dict]
    reducing_factors: list[dict]
    improvement_actions: list[dict]  # What student can do to improve
    predicted_competition_level: str  # low | medium | high | very_high


@app.post("/api/v1/ai/success-probability", response_model=SuccessProbabilityResponse)
async def predict_success(
    body: SuccessProbabilityRequest,
    current_user=Depends(get_current_user),
):
    predictor = SuccessPredictor()
    result = await predictor.predict(
        career_dna=body.career_dna,
        opportunity_id=body.opportunity_id,
        opportunity_data=body.opportunity_data,
        application_completeness=body.application_completeness,
    )
    return result


# ── AI-Enhanced Eligibility ────────────────────────────────────────────────────
class EligibilityCheckRequest(BaseModel):
    career_dna: dict
    opportunity: dict
    rule_result: Optional[dict] = None


@app.post("/api/v1/ai/eligibility/check-complex")
async def check_complex_eligibility(
    body: EligibilityCheckRequest,
    current_user=Depends(get_current_user),
):
    """
    AI-enhanced eligibility check for borderline/complex cases the rule
    engine can't confidently resolve (missing data, near-threshold values).
    """
    engine = get_eligibility_engine()
    return await engine.check_complex_eligibility(
        career_dna=body.career_dna,
        opportunity=body.opportunity,
        rule_result=body.rule_result,
    )


class EligibilityBatchRequest(BaseModel):
    career_dna: dict
    opportunities: list[dict]


@app.post("/api/v1/ai/eligibility/batch-check")
async def batch_check_eligibility(
    body: EligibilityBatchRequest,
    current_user=Depends(get_current_user),
):
    engine = get_eligibility_engine()
    return await engine.batch_check(
        career_dna=body.career_dna,
        opportunities=body.opportunities,
    )


# ── Form Intelligence ──────────────────────────────────────────────────────────
class FormFillRequest(BaseModel):
    form_fields: list[dict] = Field(..., description="List of form field definitions")
    career_dna: dict
    opportunity_id: str
    form_url: Optional[str] = None


class FormFillResponse(BaseModel):
    filled_fields: dict  # field_id → value
    confidence_per_field: dict  # field_id → confidence score
    missing_required_fields: list[str]
    warnings: list[dict]
    estimated_accuracy: float


@app.post("/api/v1/ai/form/fill", response_model=FormFillResponse)
async def fill_form(
    body: FormFillRequest,
    current_user=Depends(get_current_user),
):
    engine = get_form_engine()
    result = await engine.fill(
        form_fields=body.form_fields,
        career_dna=body.career_dna,
        opportunity_id=body.opportunity_id,
    )
    return result


class FormValidateRequest(BaseModel):
    form_fields: list[dict]
    filled_values: dict
    opportunity_id: str


@app.post("/api/v1/ai/form/validate")
async def validate_form(
    body: FormValidateRequest,
    current_user=Depends(get_current_user),
):
    engine = get_form_engine()
    result = await engine.validate(
        form_fields=body.form_fields,
        filled_values=body.filled_values,
        opportunity_id=body.opportunity_id,
    )
    return result


# ── Real Portal Auto-Fill ──────────────────────────────────────────────────────
class AutoFillRequest(BaseModel):
    portal_url: str = Field(..., description="The actual government form URL to fill")
    career_dna: dict
    opportunity_id: str


class AutoFillStepResponse(BaseModel):
    field_id: str
    label: str
    value: Optional[str]
    status: str
    note: str = ""


class AutoFillResponse(BaseModel):
    success: bool
    portal_url: str
    steps: list[AutoFillStepResponse]
    screenshot_b64: Optional[str] = None
    fields_filled: int
    fields_total: int
    requires_manual_review: list[str]
    error: Optional[str] = None


@app.post("/api/v1/ai/form/auto-fill", response_model=AutoFillResponse)
async def auto_fill_form(
    body: AutoFillRequest,
    current_user=Depends(get_current_user),
):
    """
    Actually navigate to the real government portal and fill the live form
    using the student's Career DNA. Never auto-submits — returns a screenshot
    and field-by-field report so the student can review before submitting
    themselves on the official portal.
    """
    result = await auto_fill_government_form(
        portal_url=body.portal_url,
        career_dna=body.career_dna,
        opportunity_id=body.opportunity_id,
    )
    return AutoFillResponse(
        success=result.success,
        portal_url=result.portal_url,
        steps=[
            AutoFillStepResponse(
                field_id=s.field_id,
                label=s.label,
                value=s.value,
                status=s.status,
                note=s.note,
            )
            for s in result.steps
        ],
        screenshot_b64=result.screenshot_b64,
        fields_filled=result.fields_filled,
        fields_total=result.fields_total,
        requires_manual_review=result.requires_manual_review,
        error=result.error,
    )


# ── Skill Gap Analysis ────────────────────────────────────────────────────────
class SkillGapRequest(BaseModel):
    career_dna: dict
    career_goal: Optional[str] = None
    target_opportunities: Optional[list[str]] = None


@app.post("/api/v1/ai/skill-gap")
async def analyze_skill_gap(
    body: SkillGapRequest,
    current_user=Depends(get_current_user),
):
    analyzer = SkillGapAnalyzer()
    return await analyzer.analyze(
        career_dna=body.career_dna,
        career_goal=body.career_goal,
        target_opportunities=body.target_opportunities,
    )


# ── Career Roadmap ─────────────────────────────────────────────────────────────
class RoadmapRequest(BaseModel):
    career_dna: dict
    goal: str = Field(..., min_length=10, max_length=500)
    timeline_months: int = Field(default=24, ge=3, le=120)
    language: str = Field(default="en")


@app.post("/api/v1/ai/roadmap")
async def generate_roadmap(
    body: RoadmapRequest,
    current_user=Depends(get_current_user),
):
    gen = RoadmapGenerator()
    return await gen.generate(
        career_dna=body.career_dna,
        goal=body.goal,
        timeline_months=body.timeline_months,
        language=body.language,
    )


# ── SOP Builder ───────────────────────────────────────────────────────────────
class SOPRequest(BaseModel):
    career_dna: dict
    opportunity: dict
    tone: str = Field(
        default="professional", pattern="^(professional|academic|personal)$"
    )
    word_limit: int = Field(default=500, ge=200, le=2000)
    language: str = Field(default="en")


@app.post("/api/v1/ai/sop")
async def build_sop(
    body: SOPRequest,
    current_user=Depends(get_current_user),
):
    builder = SOPBuilder()
    return await builder.generate(
        career_dna=body.career_dna,
        opportunity=body.opportunity,
        tone=body.tone,
        word_limit=body.word_limit,
        language=body.language,
    )


# ── Rejection Appeal Writer ───────────────────────────────────────────────────


class AppealRequest(BaseModel):
    application_data: dict = Field(..., description="The rejected application record")
    rejection_reason: Optional[str] = Field(
        None, description="Rejection reason as stated by authority"
    )
    student_profile: dict = Field(..., description="Student's Career DNA")
    opportunity_data: Optional[dict] = None
    language: str = Field(default="both", pattern="^(en|hi|both)$")


class GrievanceRequest(BaseModel):
    issue_type: str = Field(
        ...,
        description="Type of issue: payment_not_received | login_issue | status_stuck | etc.",
    )
    description: str = Field(..., min_length=20, max_length=1000)
    student_profile: dict
    portal: str = Field(default="NSP")


def get_appeal_writer() -> AppealWriter:
    global _appeal_writer
    if _appeal_writer is None:
        _appeal_writer = AppealWriter()
    return _appeal_writer


@app.post("/api/v1/ai/appeal")
async def write_appeal_letter(
    body: AppealRequest,
    current_user=Depends(get_current_user),
):
    """
    Generate a formal rejection appeal letter for a scholarship/job application.

    Returns letter in English and/or Hindi with:
    - Correct addressee and format
    - Grounds for appeal with relevant provisions cited
    - Enclosures checklist
    - Success probability estimate
    - Practical tips
    """
    writer = get_appeal_writer()
    return await writer.write_appeal(
        application_data=body.application_data,
        rejection_reason=body.rejection_reason,
        student_profile=body.student_profile,
        language=body.language,
        opportunity_data=body.opportunity_data,
    )


@app.post("/api/v1/ai/grievance")
async def write_grievance_letter(
    body: GrievanceRequest,
    current_user=Depends(get_current_user),
):
    """
    Write a formal grievance for portal technical issues
    (payment not received, application stuck, PFMS errors, etc.)
    """
    writer = get_appeal_writer()
    return await writer.write_grievance(
        issue_type=body.issue_type,
        description=body.description,
        student_profile=body.student_profile,
        portal=body.portal,
    )


# ── Daily Career Briefing ──────────────────────────────────────────────────────
@app.get("/api/v1/ai/briefing")
async def daily_briefing(
    career_dna: str,
    current_user=Depends(get_current_user),
):
    """Generate personalized daily career briefing for student."""
    import json as json_lib

    dna = json_lib.loads(career_dna)
    agent = get_career_twin()
    return await agent.generate_briefing(
        user_id=str(current_user.user_id),
        career_dna=dna,
    )
