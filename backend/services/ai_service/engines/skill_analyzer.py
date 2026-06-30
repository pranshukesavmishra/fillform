"""Skill Gap Analyzer — identifies what skills/certs unlock more opportunities."""
import logging
from anthropic import AsyncAnthropic
from backend.shared.config.settings import settings

logger = logging.getLogger(__name__)


class SkillGapAnalyzer:
    def __init__(self):
        self.client = AsyncAnthropic(api_key=settings.ANTHROPIC_API_KEY)

    async def analyze(
        self,
        career_dna: dict,
        career_goal: str | None = None,
        target_opportunities: list[str] | None = None,
    ) -> dict:
        prompt = f"""Analyze skill gaps for this Indian student and suggest actionable improvements.

Student Profile:
- Education: {career_dna.get('education_level', 'Unknown')} in {career_dna.get('stream', 'Unknown')}
- Current Skills: {', '.join(career_dna.get('skills', ['None listed']))}
- State: {career_dna.get('state', 'Unknown')}
- Career Goal: {career_goal or 'Not specified'}
- Age: {career_dna.get('age', 'Unknown')}

Focus on:
1. Skills/certificates that unlock government job eligibility (NIELIT, typing speed, etc.)
2. Skills that improve scholarship applications
3. Skills for career goal: {career_goal or 'general career advancement'}

For each gap, provide:
- skill_name: What to learn
- priority: high/medium/low
- opportunity_unlock_count: Approx. how many more opportunities this unlocks
- estimated_cost_inr: Cost to acquire this skill
- estimated_time_weeks: Time to acquire
- resources: List of 2-3 specific free/affordable resources (name + url if known)
- certificates: Specific certifications to get

Respond as JSON with key "gaps" containing an array of gap objects."""

        response = await self.client.messages.create(
            model=settings.CLAUDE_MODEL,
            max_tokens=1500,
            messages=[{"role": "user", "content": prompt}],
        )

        import json
        import re
        try:
            json_match = re.search(r'\{.*\}', response.content[0].text, re.DOTALL)
            if json_match:
                return json.loads(json_match.group())
        except Exception:
            pass
        return {"raw": response.content[0].text, "gaps": []}


class RoadmapGenerator:
    def __init__(self):
        self.client = AsyncAnthropic(api_key=settings.ANTHROPIC_API_KEY)

    async def generate(
        self,
        career_dna: dict,
        goal: str,
        timeline_months: int = 24,
        language: str = "en",
    ) -> dict:
        lang_instruction = "" if language == "en" else f"Respond in {language} language."
        prompt = f"""Generate a detailed career roadmap for this Indian student.

Student Profile:
- Name: {career_dna.get('full_name', 'Student')}
- Education: {career_dna.get('education_level', 'Unknown')} ({career_dna.get('marks_percent', 'N/A')}%)
- Stream: {career_dna.get('stream', 'Unknown')}
- State: {career_dna.get('state', 'Unknown')}
- Category: {career_dna.get('category', 'Unknown')}
- Income: ₹{career_dna.get('family_income_annual', 0):,}/year
- Current Skills: {', '.join(career_dna.get('skills', []))}

GOAL: {goal}
TIMELINE: {timeline_months} months
{lang_instruction}

Generate a month-by-month roadmap with:
1. phases: Array of phases, each with:
   - phase_name: Name
   - months: "Month 1-3" etc.
   - objective: What to achieve
   - steps: Array of specific actions with deadlines
   - scholarships: Relevant scholarships to apply during this phase
   - milestones: Key checkpoints

2. key_exams: Relevant exams with dates and preparation tips
3. scholarships_timeline: List of scholarships to apply (with amounts, deadlines)
4. total_estimated_cost: Cost breakdown
5. financial_aid_available: Total scholarship amount potentially available
6. success_indicators: How to know you're on track

Make it specific to India — mention actual scheme names, portal URLs where known, realistic costs.
Respond as valid JSON."""

        response = await self.client.messages.create(
            model=settings.CLAUDE_MODEL,
            max_tokens=3000,
            messages=[{"role": "user", "content": prompt}],
        )

        import json
        import re
        try:
            json_match = re.search(r'\{.*\}', response.content[0].text, re.DOTALL)
            if json_match:
                return json.loads(json_match.group())
        except Exception:
            pass
        return {"raw": response.content[0].text}
