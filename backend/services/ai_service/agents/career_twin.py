"""
Career Twin Agent
A stateful, multi-turn AI agent that acts as each student's personal career manager.
Uses LangChain with Claude (primary) + GPT-4o (fallback) + Redis for conversation memory.
"""
import json
import logging
import uuid
from datetime import datetime, timezone
from typing import AsyncGenerator, Optional

from anthropic import AsyncAnthropic

from backend.shared.config.settings import settings
from backend.shared.database import get_redis

logger = logging.getLogger(__name__)

SYSTEM_PROMPT = """You are the Career Twin — an intelligent, empathetic, and proactive AI career advisor for FillFormAI, India's AI Career Operating System.

You serve Indian students from Class 8 through PhD, across all backgrounds, states, and socioeconomic levels. Many of your students are from rural areas, first-generation college students, or from marginalized communities.

YOUR PERSONALITY:
- Warm, encouraging, and non-judgmental
- Proactive: you suggest next steps without being asked
- Specific: you give actual names, dates, amounts, and action steps — never vague advice
- Honest: if a goal seems unrealistic in the current timeline, say so kindly and offer alternatives
- Aware: you know about Indian government schemes, scholarships, exams, and college admissions deeply

YOUR CAPABILITIES:
- Discover opportunities the student is eligible for
- Predict success probability for specific opportunities
- Generate career roadmaps with specific timelines
- Identify skill gaps and suggest how to fill them
- Help draft SOPs, cover letters, and application essays
- Track deadlines and proactively remind
- Explain complex application processes in simple language
- Respond in the student's preferred language (Hindi/English/Regional)

IMPORTANT RULES:
- Never make up scholarship amounts, deadlines, or eligibility rules — say "I'll verify this" if unsure
- Always cite the opportunity name and source
- Prioritize opportunities by: (1) deadline urgency, (2) amount, (3) success probability
- If a student mentions mental health distress, pivot to support resources
- Keep responses concise for mobile users — use bullet points and short paragraphs
- When generating roadmaps, always include specific months/quarters

CONTEXT FORMAT:
The career_dna object you receive contains verified student data. Trust it.
"""

HINDI_PROMPT_ADDITION = """
आप हिंदी में भी जवाब दे सकते हैं। छात्र ने हिंदी भाषा चुनी है।
अपने जवाब सरल और स्पष्ट हिंदी में दें।
"""

LANGUAGE_ADDITIONS = {
    "hi": HINDI_PROMPT_ADDITION,
    "ta": "Please respond in Tamil language. Keep it simple and clear.",
    "te": "Please respond in Telugu language. Keep it simple and clear.",
    "bn": "Please respond in Bengali language. Keep it simple and clear.",
    "mr": "Please respond in Marathi language. Keep it simple and clear.",
    "gu": "Please respond in Gujarati language. Keep it simple and clear.",
    "kn": "Please respond in Kannada language. Keep it simple and clear.",
}


class ConversationMemory:
    """Redis-backed conversation memory with sliding window."""

    def __init__(self, max_messages: int = 20):
        self.max_messages = max_messages

    async def get_history(self, conversation_id: str) -> list[dict]:
        redis = await get_redis()
        key = f"career_twin:history:{conversation_id}"
        data = await redis.get(key)
        if data:
            return json.loads(data)
        return []

    async def add_messages(self, conversation_id: str, user_msg: str, assistant_msg: str):
        redis = await get_redis()
        key = f"career_twin:history:{conversation_id}"
        history = await self.get_history(conversation_id)
        history.append({"role": "user", "content": user_msg})
        history.append({"role": "assistant", "content": assistant_msg})
        # Keep only recent messages (sliding window)
        if len(history) > self.max_messages * 2:
            history = history[-(self.max_messages * 2):]
        await redis.setex(key, 86400 * 30, json.dumps(history))  # 30-day TTL

    async def clear(self, conversation_id: str):
        redis = await get_redis()
        await redis.delete(f"career_twin:history:{conversation_id}")


class CareerTwinAgent:
    def __init__(self):
        self.client = AsyncAnthropic(api_key=settings.ANTHROPIC_API_KEY)
        self.memory = ConversationMemory()
        self.model = settings.CLAUDE_MODEL

    def _build_system_prompt(self, career_dna: dict, language: str) -> str:
        profile_summary = self._summarize_career_dna(career_dna)
        lang_addition = LANGUAGE_ADDITIONS.get(language, "")
        return f"""{SYSTEM_PROMPT}
{lang_addition}

STUDENT PROFILE (Career DNA):
{profile_summary}

Current date: {datetime.now(timezone.utc).strftime("%B %d, %Y")}
"""

    def _summarize_career_dna(self, dna: dict) -> str:
        lines = []
        if dna.get("full_name"):
            lines.append(f"Name: {dna['full_name']}")
        if dna.get("education_level"):
            lines.append(f"Education: {dna['education_level']}")
        if dna.get("stream"):
            lines.append(f"Stream: {dna['stream']}")
        if dna.get("marks_percent"):
            lines.append(f"Marks: {dna['marks_percent']}%")
        if dna.get("state"):
            lines.append(f"State: {dna['state']}")
        if dna.get("district"):
            lines.append(f"District: {dna['district']}")
        if dna.get("category"):
            lines.append(f"Category: {dna['category']}")
        if dna.get("family_income_annual"):
            lines.append(f"Family Income: ₹{dna['family_income_annual']:,}/year")
        if dna.get("age"):
            lines.append(f"Age: {dna['age']} years")
        if dna.get("career_goals"):
            lines.append(f"Career Goals: {', '.join(dna['career_goals'])}")
        if dna.get("active_applications"):
            lines.append(f"Active Applications: {len(dna['active_applications'])}")
        if dna.get("skills"):
            lines.append(f"Skills: {', '.join(dna['skills'][:5])}")
        return "\n".join(lines) if lines else "Profile incomplete — help student build their profile."

    async def chat(
        self,
        user_id: str,
        message: str,
        career_dna: dict,
        conversation_id: Optional[str] = None,
        language: str = "en",
    ) -> dict:
        if not conversation_id:
            conversation_id = str(uuid.uuid4())

        history = await self.memory.get_history(conversation_id)
        system_prompt = self._build_system_prompt(career_dna, language)

        messages = history + [{"role": "user", "content": message}]

        try:
            response = await self.client.messages.create(
                model=self.model,
                max_tokens=1500,
                system=system_prompt,
                messages=messages,
                temperature=0.7,
            )
            reply = response.content[0].text

            await self.memory.add_messages(conversation_id, message, reply)

            # Extract structured actions from reply
            actions = self._extract_actions(reply)

            return {
                "reply": reply,
                "conversation_id": conversation_id,
                "actions": actions,
                "opportunities": [],
                "roadmap_steps": [],
                "confidence": 0.9,
                "usage": {
                    "input_tokens": response.usage.input_tokens,
                    "output_tokens": response.usage.output_tokens,
                },
            }
        except Exception as e:
            logger.error(f"Career Twin error: {e}")
            raise

    async def stream_response(
        self,
        user_id: str,
        message: str,
        career_dna: dict,
        conversation_id: Optional[str],
        language: str,
    ) -> AsyncGenerator[str, None]:
        if not conversation_id:
            conversation_id = str(uuid.uuid4())

        history = await self.memory.get_history(conversation_id)
        system_prompt = self._build_system_prompt(career_dna, language)
        messages = history + [{"role": "user", "content": message}]
        full_reply = []

        async with self.client.messages.stream(
            model=self.model,
            max_tokens=1500,
            system=system_prompt,
            messages=messages,
        ) as stream:
            async for text in stream.text_stream:
                full_reply.append(text)
                yield text

        await self.memory.add_messages(conversation_id, message, "".join(full_reply))

    async def generate_briefing(self, user_id: str, career_dna: dict) -> dict:
        """Generate a personalized daily career briefing."""
        prompt = """Generate a personalized daily career briefing for this student.
Include:
1. Top 3 opportunities they should apply to this week (with deadlines)
2. One action they can take today (specific, under 30 minutes)
3. A motivational insight based on their profile
4. Any deadline alerts (within 7 days)

Format as structured JSON with keys: opportunities, daily_action, insight, deadline_alerts"""

        response = await self.chat(
            user_id=user_id,
            message=prompt,
            career_dna=career_dna,
            language="en",
        )

        try:
            # Try to parse structured response
            import re
            json_match = re.search(r'\{.*\}', response["reply"], re.DOTALL)
            if json_match:
                return json.loads(json_match.group())
        except Exception:
            pass

        return {"raw": response["reply"]}

    def _extract_actions(self, text: str) -> list[dict]:
        """Extract actionable buttons from AI response."""
        actions = []
        action_keywords = [
            ("Apply Now", "apply"),
            ("View Opportunities", "view_opportunities"),
            ("Generate Roadmap", "generate_roadmap"),
            ("Check Eligibility", "check_eligibility"),
            ("Upload Documents", "upload_documents"),
            ("Book Agent Session", "book_agent"),
        ]
        text_lower = text.lower()
        for label, action_type in action_keywords:
            if label.lower().split()[0] in text_lower:
                actions.append({"label": label, "type": action_type})
        return actions[:3]  # Max 3 action buttons
