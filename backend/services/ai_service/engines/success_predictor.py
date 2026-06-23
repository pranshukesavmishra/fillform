"""
Success Probability Predictor
Predicts how likely a student is to succeed in a specific opportunity.
Phase 1: Rule-based + proxy signals. Phase 2+: ML model trained on outcome data.
"""
import logging
from typing import Optional
import math

logger = logging.getLogger(__name__)


class SuccessPredictor:
    """
    Computes success probability for a (student, opportunity) pair.

    Algorithm:
    1. Base probability = 1 / (estimated_competition_ratio)
    2. Adjust up/down based on student's relative standing
    3. Apply application quality multiplier
    4. Clamp to [0.05, 0.95]
    """

    async def predict(
        self,
        career_dna: dict,
        opportunity_id: str,
        opportunity_data: dict,
        application_completeness: float = 1.0,
    ) -> dict:
        boosting = []
        reducing = []
        improvements = []

        # ── Base competition estimate ─────────────────────────────────────────
        total_seats = opportunity_data.get("total_seats", 100)
        platform_applicants = opportunity_data.get("platform_applicants", 500)
        competition_score = opportunity_data.get("competition_score", 0.5)
        category = career_dna.get("category", "General")

        # Category seat adjustments (India-specific)
        category_seat_multiplier = {
            "SC": 1.8,     # Reserved seats exist
            "ST": 2.1,     # Reserved seats exist, typically fewer applicants
            "OBC": 1.4,
            "OBC-NCL": 1.4,
            "EWS": 1.3,
            "General": 0.85,  # More applicants competing for fewer seats
        }.get(category, 1.0)

        # ── Marks advantage ────────────────────────────────────────────────────
        student_marks = career_dna.get("marks_percent") or career_dna.get("marks_12th_percent", 60)
        min_marks = opportunity_data.get("eligibility_rules", {}).get("marks_min_percent", 50)
        marks_advantage = (student_marks - min_marks) / max(100 - min_marks, 1)

        if marks_advantage > 0.3:
            boosting.append({
                "factor": "marks",
                "label": f"Your marks ({student_marks}%) are well above minimum ({min_marks}%)",
                "impact": "+12%",
            })
        elif marks_advantage > 0.1:
            boosting.append({
                "factor": "marks",
                "label": f"Your marks ({student_marks}%) exceed minimum ({min_marks}%)",
                "impact": "+6%",
            })
        else:
            reducing.append({
                "factor": "marks",
                "label": f"Your marks are close to minimum requirement",
                "impact": "-8%",
            })

        # ── Geography advantage ────────────────────────────────────────────────
        state = career_dna.get("state", "")
        allowed_states = opportunity_data.get("eligibility_rules", {}).get("states_allowed", ["ALL"])
        if "ALL" not in allowed_states and state in allowed_states:
            boosting.append({
                "factor": "geography",
                "label": f"State-specific opportunity — less competition",
                "impact": "+8%",
            })

        # ── Document readiness ─────────────────────────────────────────────────
        required_docs = opportunity_data.get("documents_required", [])
        available_docs = career_dna.get("uploaded_documents", [])
        doc_readiness = len([d for d in required_docs if d in available_docs]) / max(len(required_docs), 1)

        if doc_readiness < 1.0:
            missing_count = len(required_docs) - int(doc_readiness * len(required_docs))
            reducing.append({
                "factor": "documents",
                "label": f"{missing_count} required document(s) not yet uploaded",
                "impact": f"-{missing_count * 5}%",
            })
            improvements.append({
                "action": "Upload missing documents",
                "impact": f"+{missing_count * 5}%",
                "type": "upload_documents",
                "urgency": "high",
            })

        # ── Application completeness ───────────────────────────────────────────
        if application_completeness < 0.8:
            reducing.append({
                "factor": "application_completeness",
                "label": "Application is incomplete",
                "impact": f"-{int((1 - application_completeness) * 20)}%",
            })
            improvements.append({
                "action": "Complete all application sections",
                "impact": f"+{int((1 - application_completeness) * 20)}%",
                "type": "complete_application",
                "urgency": "high",
            })
        elif application_completeness == 1.0:
            boosting.append({
                "factor": "application_completeness",
                "label": "Application is 100% complete",
                "impact": "+5%",
            })

        # ── Deadline timing ────────────────────────────────────────────────────
        from datetime import date, datetime
        deadline = opportunity_data.get("deadline")
        if deadline:
            if isinstance(deadline, str):
                deadline = datetime.strptime(deadline, "%Y-%m-%d").date()
            days_remaining = (deadline - date.today()).days
            if days_remaining <= 3:
                reducing.append({
                    "factor": "deadline",
                    "label": f"Only {days_remaining} days until deadline — rushed applications score lower",
                    "impact": "-10%",
                })
                improvements.append({
                    "action": "Submit today to avoid last-minute errors",
                    "impact": "+10%",
                    "type": "submit_now",
                    "urgency": "critical",
                })
            elif days_remaining >= 14:
                boosting.append({
                    "factor": "deadline",
                    "label": "Plenty of time to prepare a quality application",
                    "impact": "+3%",
                })

        # ── Compute final probability ──────────────────────────────────────────
        base_probability = 0.5
        base_probability *= category_seat_multiplier
        base_probability *= (1 - competition_score * 0.6)
        base_probability += marks_advantage * 0.2
        base_probability *= (0.7 + application_completeness * 0.3)
        base_probability *= (0.8 + doc_readiness * 0.2)

        # Apply boosts and reductions
        boost_total = sum(
            float(b["impact"].replace("%", "").replace("+", "")) / 100
            for b in boosting
            if "%" in b.get("impact", "")
        )
        reduce_total = sum(
            abs(float(r["impact"].replace("%", "").replace("-", ""))) / 100
            for r in reducing
            if "%" in r.get("impact", "")
        )
        final_probability = base_probability + boost_total - reduce_total

        # Sample size affects confidence
        historical_count = opportunity_data.get("platform_success_count", 0) + platform_applicants
        confidence = min(0.95, 0.4 + math.log10(max(historical_count, 1)) * 0.15)

        competition_level = (
            "low" if competition_score < 0.3
            else "medium" if competition_score < 0.6
            else "high" if competition_score < 0.8
            else "very_high"
        )

        return {
            "probability": round(max(0.05, min(0.95, final_probability)), 3),
            "confidence": round(confidence, 3),
            "sample_size": historical_count,
            "boosting_factors": boosting,
            "reducing_factors": reducing,
            "improvement_actions": sorted(
                improvements,
                key=lambda x: {"critical": 0, "high": 1, "medium": 2, "low": 3}.get(x.get("urgency", "low"), 3)
            ),
            "predicted_competition_level": competition_level,
        }
