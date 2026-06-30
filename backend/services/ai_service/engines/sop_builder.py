"""SOP / Personal Statement Builder."""
from anthropic import AsyncAnthropic
from backend.shared.config.settings import settings


class SOPBuilder:
    def __init__(self):
        self.client = AsyncAnthropic(api_key=settings.ANTHROPIC_API_KEY)

    async def generate(
        self,
        career_dna: dict,
        opportunity: dict,
        tone: str = "professional",
        word_limit: int = 500,
        language: str = "en",
    ) -> dict:
        lang_note = f"Write in {language} language." if language != "en" else ""

        prompt = f"""Write a compelling Statement of Purpose/Personal Statement for this scholarship/opportunity application.

Student Background:
- Name: {career_dna.get('full_name', 'Student')}
- Education: {career_dna.get('education_level')} in {career_dna.get('stream')}
- Marks: {career_dna.get('marks_percent')}%
- Institution: {career_dna.get('institution_name', 'Not specified')}
- State/District: {career_dna.get('state')}, {career_dna.get('district')}
- Family Background: Income ₹{career_dna.get('family_income_annual', 0):,}/year
- Category: {career_dna.get('category')}
- Career Goals: {', '.join(career_dna.get('career_goals', ['Not specified']))}
- Achievements: {', '.join(career_dna.get('achievements', ['None listed']))}
- Challenges Overcome: {career_dna.get('background_challenges', 'Not specified')}

Opportunity: {opportunity.get('title')}
Type: {opportunity.get('category')}
Issuing Authority: {opportunity.get('issuing_authority', 'Government of India')}

Requirements:
- Word limit: approximately {word_limit} words
- Tone: {tone}
- {lang_note}

The SOP should:
1. Open with a compelling hook that reflects the student's authentic background
2. Explain their educational journey and achievements
3. Connect their background to their career goals
4. Explain why THIS specific opportunity is important to them
5. Show how they will contribute back to their community/country
6. Close with a strong, memorable statement

IMPORTANT: Make it authentic, not generic. Reference their actual marks, state, and background.
Do NOT use clichés like "Since childhood I dreamed of..." — be specific and real.

Return JSON with:
- sop_text: The full SOP text
- word_count: Actual word count
- key_themes: Array of 3-5 themes used
- improvement_tips: 2-3 ways to personalize further
- alternative_opening: An alternative first paragraph"""

        response = await self.client.messages.create(
            model=settings.CLAUDE_MODEL,
            max_tokens=2000,
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
        return {"sop_text": response.content[0].text, "word_count": len(response.content[0].text.split())}
