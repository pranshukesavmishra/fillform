"""
AI-Enhanced Eligibility Engine
Uses Claude to handle complex eligibility cases beyond simple rule matching.
"""

import json
import logging
from typing import Optional

from anthropic import AsyncAnthropic

from backend.shared.config.settings import settings

logger = logging.getLogger(__name__)


class AIEligibilityEngine:
    def __init__(self):
        self.client = AsyncAnthropic(api_key=settings.ANTHROPIC_API_KEY)

    async def check_complex_eligibility(
        self,
        career_dna: dict,
        opportunity: dict,
        rule_result: Optional[dict] = None,
    ) -> dict:
        """
        AI-enhanced eligibility for complex cases where rule engine is uncertain.
        Called when rule-based check has borderline criteria or missing data.
        """
        prompt = f"""You are an expert on Indian government scholarship and job eligibility rules.

Analyze if this student is eligible for this opportunity.

STUDENT PROFILE:
{json.dumps(career_dna, indent=2, default=str)}

OPPORTUNITY:
Title: {opportunity.get("title", "Unknown")}
Category: {opportunity.get("category", "Unknown")}
Issuing Authority: {opportunity.get("issuing_authority", "Unknown")}
Eligibility Rules: {json.dumps(opportunity.get("eligibility_rules", {}), indent=2)}
Description: {opportunity.get("short_description", "")}

RULE ENGINE RESULT (if available):
{json.dumps(rule_result, indent=2) if rule_result else "Not run yet"}

Provide your analysis as JSON with these exact keys:
{{
  "is_eligible": true/false,
  "confidence": 0.0-1.0,
  "matching_criteria": ["list of met criteria"],
  "failing_criteria": ["list of unmet criteria"],
  "borderline_criteria": ["list of borderline criteria"],
  "missing_data": ["list of data needed but absent"],
  "success_probability": 0.0-1.0,
  "recommendation": "brief actionable advice for student",
  "alternative_opportunities": ["similar opportunities if not eligible"]
}}

Be precise. If income/marks are borderline (within 5%), flag as borderline not failing."""

        try:
            response = await self.client.messages.create(
                model="claude-haiku-4-5-20251001",
                max_tokens=800,
                messages=[{"role": "user", "content": prompt}],
            )
            text = response.content[0].text
            import re

            match = re.search(r"\{.*\}", text, re.DOTALL)
            if match:
                return json.loads(match.group())
        except Exception as e:
            logger.error(f"AI eligibility check error: {e}")

        return {
            "is_eligible": False,
            "confidence": 0.0,
            "matching_criteria": [],
            "failing_criteria": ["AI analysis unavailable"],
            "borderline_criteria": [],
            "missing_data": [],
            "success_probability": None,
            "recommendation": "Please check eligibility manually on the portal.",
            "alternative_opportunities": [],
        }

    async def batch_check(
        self,
        career_dna: dict,
        opportunities: list[dict],
    ) -> list[dict]:
        """Check eligibility for multiple opportunities efficiently."""
        results = []
        for opp in opportunities:
            result = await self.check_complex_eligibility(career_dna, opp)
            result["opportunity_id"] = opp.get("id", "")
            results.append(result)
        return sorted(results, key=lambda r: (-r["confidence"], not r["is_eligible"]))
