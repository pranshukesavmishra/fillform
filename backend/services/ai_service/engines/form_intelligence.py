"""
Form Intelligence Engine — The Company's Core Moat.

Understands every form field semantically, maps to student profile,
validates, and learns from every correction to improve accuracy over time.
"""

import json
import logging
import re
from typing import Optional

from anthropic import AsyncAnthropic
from backend.shared.config.settings import settings

logger = logging.getLogger(__name__)

# Master field mapper: canonical field types → career DNA paths
FIELD_TYPE_MAP = {
    # Identity
    "full_name": ["career_dna.full_name", "career_dna.name"],
    "father_name": ["career_dna.father_name"],
    "mother_name": ["career_dna.mother_name"],
    "dob": ["career_dna.date_of_birth"],
    "gender": ["career_dna.gender"],
    "category": ["career_dna.category"],
    "aadhaar": ["career_dna.aadhaar_last4"],
    # Contact
    "mobile": ["career_dna.phone"],
    "email": ["career_dna.email"],
    "address_line1": ["career_dna.address.line1"],
    "address_line2": ["career_dna.address.line2"],
    "city": ["career_dna.address.city", "career_dna.district"],
    "state": ["career_dna.state"],
    "pincode": ["career_dna.address.pincode"],
    # Education
    "education_level": ["career_dna.education_level"],
    "stream": ["career_dna.stream"],
    "board": ["career_dna.board"],
    "school_name": ["career_dna.institution_name"],
    "college_name": ["career_dna.institution_name"],
    "roll_number": ["career_dna.roll_number"],
    "marks_10th": ["career_dna.marks_10th_percent"],
    "marks_12th": ["career_dna.marks_12th_percent"],
    "cgpa": ["career_dna.cgpa"],
    "passing_year": ["career_dna.passing_year"],
    # Financial
    "family_income": ["career_dna.family_income_annual"],
    "bank_account": ["career_dna.bank.account_number"],
    "bank_ifsc": ["career_dna.bank.ifsc"],
    "bank_name": ["career_dna.bank.bank_name"],
    # Documents
    "aadhaar_number": ["career_dna.aadhaar_number"],
    "income_certificate_no": ["career_dna.documents.income_certificate.number"],
    "caste_certificate_no": ["career_dna.documents.caste_certificate.number"],
}

# Common field labels → canonical types (learned + hardcoded)
LABEL_TO_TYPE = {
    # Name variants
    r"full.?name|applicant.?name|student.?name|name.?of.?student": "full_name",
    r"father.?name|father.?full.?name": "father_name",
    r"mother.?name|mother.?full.?name": "mother_name",
    # DOB variants
    r"date.?of.?birth|d\.?o\.?b|birth.?date|जन्म.?तिथि": "dob",
    # Contact variants
    r"mobile|phone|contact.?number|whatsapp|मोबाइल": "mobile",
    r"email|e-mail|ईमेल": "email",
    # Category variants
    r"category|caste|जाति|वर्ग|sc.?st.?obc": "category",
    # Income variants
    r"annual.?income|family.?income|household.?income|वार्षिक.?आय": "family_income",
    # Bank variants
    r"bank.?account|account.?number|खाता.?संख्या": "bank_account",
    r"ifsc|ifsc.?code|bank.?code": "bank_ifsc",
    r"bank.?name|name.?of.?bank": "bank_name",
    # Marks variants
    r"10th.?marks|class.?10.?marks|matriculation.?marks|tenth.?percent": "marks_10th",
    r"12th.?marks|class.?12.?marks|intermediate.?marks|twelfth.?percent|10\+2": "marks_12th",
    r"cgpa|gpa|cumulative.?grade": "cgpa",
    # State/City
    r"state|राज्य": "state",
    r"district|जिला": "city",
    r"pin.?code|postal.?code|zip": "pincode",
}


def _get_nested_value(dna: dict, path: str) -> Optional[str]:
    """Get value from nested dict using dot notation."""
    parts = path.replace("career_dna.", "").split(".")
    current = dna
    for part in parts:
        if isinstance(current, dict):
            current = current.get(part)
        else:
            return None
    return str(current) if current is not None else None


def _classify_field_type(label: str, field_id: str, field_type: str) -> Optional[str]:
    """Classify a form field to a canonical type using regex patterns."""
    search_text = f"{label} {field_id} {field_type}".lower()
    for pattern, canonical_type in LABEL_TO_TYPE.items():
        if re.search(pattern, search_text, re.IGNORECASE):
            return canonical_type
    return None


def _format_value(canonical_type: str, raw_value: str, field_config: dict) -> str:
    """Format a value according to field requirements."""
    if not raw_value:
        return raw_value

    # Date formatting
    if canonical_type == "dob":
        try:
            from dateutil.parser import parse

            dt = parse(raw_value)
            fmt = field_config.get("date_format", "%d/%m/%Y")
            return dt.strftime(fmt)
        except Exception:
            return raw_value

    # Phone formatting
    if canonical_type == "mobile":
        cleaned = re.sub(r"[^0-9]", "", raw_value)
        if cleaned.startswith("91") and len(cleaned) == 12:
            cleaned = cleaned[2:]
        if field_config.get("include_country_code"):
            return f"+91{cleaned}"
        return cleaned

    # Income formatting (some forms want in lakhs, some in rupees)
    if canonical_type == "family_income":
        try:
            amount = float(raw_value.replace(",", ""))
            unit = field_config.get("income_unit", "rupees")
            if unit == "lakhs":
                return f"{amount / 100000:.2f}"
            return str(int(amount))
        except Exception:
            return raw_value

    # Category normalization
    if canonical_type == "category":
        category_map = {
            "SC": ["sc", "scheduled caste", "अनुसूचित जाति"],
            "ST": ["st", "scheduled tribe", "अनुसूचित जनजाति"],
            "OBC": ["obc", "other backward class", "अन्य पिछड़ा वर्ग"],
            "OBC-NCL": ["obc-ncl", "obc ncl", "non creamy layer"],
            "General": ["general", "gen", "unreserved", "सामान्य"],
            "EWS": ["ews", "economically weaker section"],
        }
        val_lower = raw_value.lower()
        for canonical, variants in category_map.items():
            if val_lower in variants or any(v in val_lower for v in variants):
                # Check what format the form expects
                expected_values = field_config.get("options", [])
                if expected_values:
                    for opt in expected_values:
                        if canonical.lower() in opt.lower():
                            return opt
                return canonical

    return raw_value


async def _llm_classify_field(
    client: AsyncAnthropic,
    field: dict,
    career_dna: dict,
) -> tuple[Optional[str], float]:
    """Use Claude to classify ambiguous fields and extract values."""
    prompt = f"""You are analyzing a government form field to determine what student data to fill in.

Form field:
- Label: {field.get("label", "")}
- ID: {field.get("id", "")}
- Type: {field.get("type", "text")}
- Options: {field.get("options", [])}
- Required: {field.get("required", False)}
- Max length: {field.get("max_length", "none")}
- Placeholder: {field.get("placeholder", "")}

Student profile summary:
- Name: {career_dna.get("full_name", "Unknown")}
- Education: {career_dna.get("education_level", "Unknown")}
- State: {career_dna.get("state", "Unknown")}
- Category: {career_dna.get("category", "Unknown")}

Task: Determine:
1. The canonical field type (e.g., "full_name", "dob", "family_income")
2. The exact value to fill from the student profile
3. Confidence (0-1)

Respond in JSON: {{"field_type": "...", "value": "...", "confidence": 0.9, "reason": "..."}}
If you cannot determine the value, set value to null."""

    try:
        response = await client.messages.create(
            model="claude-haiku-4-5-20251001",  # Fast + cheap for classification
            max_tokens=200,
            messages=[{"role": "user", "content": prompt}],
        )
        result = json.loads(response.content[0].text)
        return result.get("value"), result.get("confidence", 0.5)
    except Exception as e:
        logger.error(f"LLM field classification error: {e}")
        return None, 0.0


class FormIntelligenceEngine:
    def __init__(self):
        self.client = AsyncAnthropic(api_key=settings.ANTHROPIC_API_KEY)

    async def fill(
        self,
        form_fields: list[dict],
        career_dna: dict,
        opportunity_id: str,
    ) -> dict:
        filled = {}
        confidence = {}
        missing_required = []
        warnings = []

        for field in form_fields:
            field_id = field.get("id") or field.get("name") or ""
            label = field.get("label", "")
            required = field.get("required", False)

            # Step 1: Try rule-based classification
            canonical_type = _classify_field_type(
                label, field_id, field.get("type", "")
            )
            value = None
            conf = 0.0

            if canonical_type and canonical_type in FIELD_TYPE_MAP:
                for path in FIELD_TYPE_MAP[canonical_type]:
                    extracted = _get_nested_value(career_dna, path)
                    if extracted:
                        value = _format_value(canonical_type, extracted, field)
                        conf = 0.92
                        break

            # Step 2: Fallback to LLM for ambiguous fields
            if value is None and settings.ENABLE_AI_FORM_FILL:
                value, conf = await _llm_classify_field(self.client, field, career_dna)

            if value:
                filled[field_id] = value
                confidence[field_id] = conf

                # Validate against known rules
                if field.get("max_length") and len(str(value)) > field["max_length"]:
                    warnings.append(
                        {
                            "field_id": field_id,
                            "type": "length_exceeded",
                            "message": f"Value too long for {label}. Max {field['max_length']} chars.",
                        }
                    )
            elif required:
                missing_required.append(field_id)

        estimated_accuracy = (
            sum(confidence.values()) / len(confidence) if confidence else 0.0
        )

        return {
            "filled_fields": filled,
            "confidence_per_field": confidence,
            "missing_required_fields": missing_required,
            "warnings": warnings,
            "estimated_accuracy": round(estimated_accuracy, 3),
        }

    async def validate(
        self,
        form_fields: list[dict],
        filled_values: dict,
        opportunity_id: str,
    ) -> dict:
        """Validate filled form and return categorized errors."""
        critical_errors = []
        major_errors = []
        warnings = []

        field_map = {f.get("id", f.get("name", "")): f for f in form_fields}

        for field_id, value in filled_values.items():
            field = field_map.get(field_id, {})
            if not field:
                continue

            label = field.get("label", field_id)
            field_type = field.get("type", "text")

            # Required check
            if field.get("required") and not value:
                critical_errors.append(
                    {
                        "field_id": field_id,
                        "label": label,
                        "issue": "Required field is empty",
                        "severity": "critical",
                    }
                )
                continue

            if not value:
                continue

            str_value = str(value)

            # Pattern validation
            if pattern := field.get("pattern"):
                import re as _re

                if not _re.fullmatch(pattern, str_value):
                    major_errors.append(
                        {
                            "field_id": field_id,
                            "label": label,
                            "issue": f"Format mismatch. Expected: {field.get('pattern_description', pattern)}",
                            "severity": "major",
                        }
                    )

            # Length validation
            if max_len := field.get("max_length"):
                if len(str_value) > max_len:
                    major_errors.append(
                        {
                            "field_id": field_id,
                            "label": label,
                            "issue": f"Too long ({len(str_value)} chars, max {max_len})",
                            "severity": "major",
                        }
                    )

            # Type-specific validations
            if field_type == "email" and "@" not in str_value:
                major_errors.append(
                    {
                        "field_id": field_id,
                        "label": label,
                        "issue": "Invalid email",
                        "severity": "major",
                    }
                )

            if field_type == "tel":
                digits = re.sub(r"[^0-9]", "", str_value)
                if len(digits) not in (10, 12):
                    major_errors.append(
                        {
                            "field_id": field_id,
                            "label": label,
                            "issue": "Invalid phone number",
                            "severity": "major",
                        }
                    )

            # Option validation
            if options := field.get("options"):
                if str_value not in options and str_value.lower() not in [
                    o.lower() for o in options
                ]:
                    major_errors.append(
                        {
                            "field_id": field_id,
                            "label": label,
                            "issue": f"'{str_value}' is not a valid option",
                            "severity": "major",
                        }
                    )

        is_valid = len(critical_errors) == 0 and len(major_errors) == 0
        confidence = 1.0 - (
            len(critical_errors) * 0.3 + len(major_errors) * 0.15 + len(warnings) * 0.05
        )

        return {
            "is_valid": is_valid,
            "critical_errors": critical_errors,
            "major_errors": major_errors,
            "warnings": warnings,
            "confidence": max(0.0, confidence),
            "total_issues": len(critical_errors) + len(major_errors) + len(warnings),
        }
