"""
Rejection Appeal Writer

When a scholarship/job application is rejected, most students give up.
This engine uses Claude to write a formal, persuasive appeal letter
in the correct format for Indian government authorities.

20-30% of soft rejections are overturnable with a proper appeal.
"""

import json
import logging
from typing import Optional

import anthropic

from backend.shared.config.settings import settings

logger = logging.getLogger(__name__)

# Common rejection reasons and their appeal strategies
REJECTION_STRATEGIES = {
    "income_limit_exceeded": "Challenge the income calculation — include agriculture income exclusions, request re-verification, cite family circumstances",
    "marks_below_cutoff": "Appeal for borderline cases — cite improvement trend, medical/family circumstances, request grace marks review",
    "document_missing": "Attach the missing document now, request one-time relaxation citing submission portal errors",
    "category_mismatch": "Provide certificate issued by correct authority, request re-evaluation",
    "late_submission": "Cite technical issues on government portal, attach screenshots, cite precedent of similar cases being accepted",
    "duplicate_application": "Clarify which application is genuine, request withdrawal of duplicate",
    "age_limit": "Verify date of birth certificate, check for age relaxation provisions for category",
    "domicile_issue": "Provide updated domicile certificate, cite continuous residence proof",
    "bank_details_mismatch": "Provide corrected bank details, request PFMS re-verification",
    "general": "Request detailed rejection reason, appeal on merit and circumstances",
}

APPEAL_SYSTEM_PROMPT = """You are an expert in Indian government scholarship and job application appeals.
You have deep knowledge of:
- Indian government scholarship schemes (NSP, UP Scholarship, PFMS, state schemes)
- Government job recruitment processes (SSC, UPSC, Railway, State PSCs, Police)
- Legal provisions for appeals in administrative proceedings
- Formal letter writing in both Hindi and English
- Common grounds for successful appeals in each category

Your task is to write a formal, persuasive appeal letter that:
1. Uses correct formal salutation and address format for the authority
2. Clearly states the grounds for appeal with specific provisions/rules cited
3. Is emotionally compelling while remaining professionally appropriate
4. Requests a specific action (re-evaluation, document verification, etc.)
5. Includes all mandatory enclosures as a checklist
6. Is written in the applicant's preferred language (Hindi/English/both)

IMPORTANT:
- NEVER fabricate facts or documents
- Only use information provided about the student
- Cite actual scheme rules and provisions where possible
- Keep letter under 500 words (government authorities don't read long letters)
- Format dates as DD/MM/YYYY (Indian standard)
- Use formal Hindi if language preference is Hindi"""


class AppealWriter:
    def __init__(self):
        self.client = anthropic.AsyncAnthropic(api_key=settings.anthropic_api_key)
        self.model = settings.claude_model  # sonnet for quality

    async def write_appeal(
        self,
        application_data: dict,
        rejection_reason: Optional[str],
        student_profile: dict,
        language: str = "both",
        opportunity_data: Optional[dict] = None,
    ) -> dict:
        """
        Generate a formal appeal letter.

        Returns:
            {
                "letter_english": str,
                "letter_hindi": str | None,
                "addressee": str,
                "subject_line": str,
                "enclosures": list[str],
                "key_grounds": list[str],
                "success_probability": float,
                "tips": list[str],
                "deadline_note": str | None,
            }
        """
        strategy = REJECTION_STRATEGIES.get(
            _classify_rejection(rejection_reason), REJECTION_STRATEGIES["general"]
        )

        opp_name = (opportunity_data or {}).get("title", "the scholarship/opportunity")
        opp_authority = (opportunity_data or {}).get(
            "issuing_authority", "the concerned authority"
        )
        student_name = student_profile.get("full_name", "Applicant")
        student_reg = application_data.get("registration_number", "N/A")
        submission_date = application_data.get("submitted_at", "N/A")
        rejection_date = application_data.get("outcome_date", "N/A")

        prompt = f"""Write a formal appeal letter for the following case:

APPLICANT DETAILS:
- Name: {student_name}
- Registration/Application No: {student_reg}
- Category: {student_profile.get("category", "OBC")}
- Education: {student_profile.get("education_level", "12th Pass")} — {student_profile.get("marks_12th_percent", "")}% marks
- State: {student_profile.get("state", "Uttar Pradesh")}
- Family Income: ₹{student_profile.get("family_income_annual", "N/A")}/year

APPLICATION:
- Scheme/Opportunity: {opp_name}
- Issuing Authority: {opp_authority}
- Application Date: {submission_date}
- Rejection Date: {rejection_date}
- Rejection Reason (as stated): {rejection_reason or "Not specified / No reason given"}

APPEAL STRATEGY TO USE:
{strategy}

LANGUAGE: {language} (if "both", write English first, then Hindi translation. If "hindi", write only in Hindi. If "english", write only in English.)

OUTPUT FORMAT (JSON):
{{
  "letter_english": "Full formal letter in English",
  "letter_hindi": "Full formal letter in Hindi (or null if not requested)",
  "addressee": "Exact title and address line for the envelope",
  "subject_line": "RE: Appeal Against Rejection of [scheme name]",
  "enclosures": ["List", "of", "documents", "to", "attach"],
  "key_grounds": ["Ground 1", "Ground 2", "Ground 3"],
  "success_probability": 0.0 to 1.0,
  "tips": ["Practical tip 1", "Practical tip 2"],
  "deadline_note": "Appeals must be filed within X days of rejection (or null)"
}}

Write the letters NOW. Make them persuasive, specific, and professionally formatted."""

        try:
            response = await self.client.messages.create(
                model=self.model,
                max_tokens=4000,
                system=APPEAL_SYSTEM_PROMPT,
                messages=[{"role": "user", "content": prompt}],
            )

            raw = response.content[0].text.strip()
            # Extract JSON from response
            if "```json" in raw:
                raw = raw.split("```json")[1].split("```")[0].strip()
            elif "```" in raw:
                raw = raw.split("```")[1].split("```")[0].strip()

            result = json.loads(raw)

            # Add metadata
            result["application_id"] = application_data.get("id")
            result["generated_for"] = student_name
            result["scheme_name"] = opp_name

            return result

        except json.JSONDecodeError:
            logger.error("Claude returned non-JSON for appeal writer")
            return _fallback_appeal(
                student_name, opp_name, rejection_reason, student_profile
            )
        except Exception as e:
            logger.error(f"Appeal writer error: {e}")
            raise

    async def write_grievance(
        self,
        issue_type: str,
        description: str,
        student_profile: dict,
        portal: str = "NSP",
    ) -> dict:
        """
        Write a formal grievance for portal technical issues
        (e.g., payment not received, application stuck, login not working).
        """
        prompt = f"""Write a formal grievance letter for:

STUDENT: {student_profile.get("full_name")} — {student_profile.get("phone", "")}
PORTAL: {portal}
ISSUE TYPE: {issue_type}
DESCRIPTION: {description}

Write a concise grievance in formal English AND Hindi.
Include: what happened, when, what was expected, what action is requested.
Address to: The Grievance Officer, {portal}.
Output as JSON with keys: letter_english, letter_hindi, reference_portals (list of helplines/portals to escalate), tips."""

        response = await self.client.messages.create(
            model="claude-haiku-4-5-20251001",  # Haiku for simple grievances
            max_tokens=2000,
            messages=[{"role": "user", "content": prompt}],
        )
        raw = response.content[0].text.strip()
        if "```json" in raw:
            raw = raw.split("```json")[1].split("```")[0].strip()
        try:
            return json.loads(raw)
        except Exception:
            return {
                "letter_english": raw,
                "letter_hindi": None,
                "reference_portals": [],
                "tips": [],
            }


def _classify_rejection(reason: Optional[str]) -> str:
    """Map free-text rejection reason to a strategy key."""
    if not reason:
        return "general"
    reason_lower = reason.lower()
    if any(w in reason_lower for w in ["income", "salary", "earning"]):
        return "income_limit_exceeded"
    if any(w in reason_lower for w in ["mark", "percentage", "score", "grade"]):
        return "marks_below_cutoff"
    if any(w in reason_lower for w in ["document", "certificate", "missing"]):
        return "document_missing"
    if any(w in reason_lower for w in ["category", "caste", "obc", "sc", "st", "ews"]):
        return "category_mismatch"
    if any(w in reason_lower for w in ["late", "deadline", "time", "expired"]):
        return "late_submission"
    if any(w in reason_lower for w in ["duplicate", "already", "applied"]):
        return "duplicate_application"
    if any(w in reason_lower for w in ["age", "born", "dob"]):
        return "age_limit"
    if any(w in reason_lower for w in ["domicile", "residence", "state"]):
        return "domicile_issue"
    if any(w in reason_lower for w in ["bank", "account", "ifsc", "pfms"]):
        return "bank_details_mismatch"
    return "general"


def _fallback_appeal(name, scheme, reason, profile) -> dict:
    """Returns a minimal appeal when Claude is unavailable."""
    return {
        "letter_english": f"""To,
The Scholarship Committee,
{scheme}

Subject: Appeal Against Rejection of Scholarship Application

Respected Sir/Madam,

I, {name}, wish to respectfully appeal against the rejection of my scholarship application for {scheme}.

The stated reason for rejection was: {reason or "not specified"}.

I kindly request you to re-evaluate my application and provide an opportunity to submit any additional documents required.

Yours faithfully,
{name}
Date: {__import__("datetime").date.today().strftime("%d/%m/%Y")}""",
        "letter_hindi": None,
        "addressee": f"The Scholarship Committee, {scheme}",
        "subject_line": f"RE: Appeal Against Rejection — {scheme}",
        "enclosures": ["Application copy", "Rejection letter", "Supporting documents"],
        "key_grounds": ["Request for re-evaluation"],
        "success_probability": 0.3,
        "tips": [
            "Submit appeal within 30 days of rejection",
            "Keep a copy of everything you send",
        ],
        "deadline_note": "Most schemes allow 30–60 days for appeal",
        "scheme_name": scheme,
        "generated_for": name,
    }
