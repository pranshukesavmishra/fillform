"""
FillFormAI - AI Service
Handles: Career Twin, Eligibility AI, Success Predictor, Form Fill Intelligence,
         Skill Gap Analysis, Roadmap Generation, SOP Builder
"""
import logging
from typing import Optional, AsyncGenerator
import json

from fastapi import FastAPI, Depends, HTTPException
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
    confidence: float   # 0-1, based on sample size
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
    tone: str = Field(default="professional", pattern="^(professional|academic|personal)$")
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
