"""
Web Form Auto-Filler — Navigates real government portals and fills forms live.

This is the capability that turns "AI suggests values" into "AI actually fills
the form on scholarships.gov.in / scholarship.up.gov.in / ssc.nic.in etc."

Flow:
  1. Launch headless Chromium via Playwright
  2. Navigate to the portal URL
  3. Extract all visible form fields (input/select/textarea) with labels
  4. Run them through FormIntelligenceEngine to get values from the student's Career DNA
  5. Fill each field in the live page, respecting field type (text/select/radio/checkbox)
  6. Screenshot before submit so the student can review (we NEVER auto-submit
     government forms — final submit is always a deliberate human action)
  7. Return a step-by-step report + screenshot for the user to confirm
"""

import base64
import logging
import re
from dataclasses import dataclass, field
from typing import Optional

from playwright.async_api import async_playwright, Page

from backend.services.ai_service.engines.form_intelligence import FormIntelligenceEngine

logger = logging.getLogger(__name__)

# Government portals often block headless detection / have self-signed certs
LAUNCH_ARGS = ["--disable-blink-features=AutomationControlled"]


@dataclass
class FillStep:
    field_id: str
    label: str
    value: Optional[str]
    status: str  # filled | skipped | failed | needs_review
    note: str = ""


@dataclass
class AutoFillResult:
    success: bool
    portal_url: str
    steps: list[FillStep] = field(default_factory=list)
    screenshot_b64: Optional[str] = None
    fields_filled: int = 0
    fields_total: int = 0
    requires_manual_review: list[str] = field(default_factory=list)
    error: Optional[str] = None


async def _extract_form_fields(page: Page) -> list[dict]:
    """Extract all fillable fields from the current page with best-effort labels."""
    fields = await page.evaluate(
        """
        () => {
            const results = [];
            const elements = document.querySelectorAll('input, select, textarea');
            elements.forEach((el, idx) => {
                const type = (el.type || el.tagName).toLowerCase();
                if (['submit', 'button', 'hidden', 'image', 'reset'].includes(type)) return;

                // Find label: explicit <label for>, wrapping label, aria-label, placeholder, or preceding text
                let label = '';
                if (el.id) {
                    const lbl = document.querySelector(`label[for="${el.id}"]`);
                    if (lbl) label = lbl.innerText.trim();
                }
                if (!label && el.closest('label')) {
                    label = el.closest('label').innerText.trim();
                }
                if (!label) label = el.getAttribute('aria-label') || '';
                if (!label) label = el.getAttribute('placeholder') || '';
                if (!label && el.previousElementSibling) {
                    label = el.previousElementSibling.innerText?.trim() || '';
                }

                let options = [];
                if (el.tagName.toLowerCase() === 'select') {
                    options = Array.from(el.options).map(o => o.text.trim()).filter(Boolean);
                }

                results.push({
                    index: idx,
                    id: el.id || el.name || `field_${idx}`,
                    name: el.name || '',
                    label: label,
                    type: type,
                    required: el.required || false,
                    max_length: el.maxLength > 0 ? el.maxLength : null,
                    options: options,
                    visible: el.offsetParent !== null,
                });
            });
            return results;
        }
        """
    )
    return [f for f in fields if f.get("visible")]


def _selector_for(field_info: dict) -> str:
    fid = field_info.get("id", "")
    name = field_info.get("name", "")
    if fid and not fid.startswith("field_"):
        return f"#{fid}" if not _looks_like_css_unsafe(fid) else f'[id="{fid}"]'
    if name:
        return f'[name="{name}"]'
    return f"#{fid}"


def _looks_like_css_unsafe(s: str) -> bool:
    return bool(re.search(r"[^\w-]", s))


async def _fill_field(page: Page, field_info: dict, value: str) -> tuple[str, str]:
    """Fill a single field in the live page. Returns (status, note)."""
    selector = _selector_for(field_info)
    field_type = field_info.get("type", "text")

    try:
        locator = page.locator(selector).first
        if await locator.count() == 0:
            return "failed", "Element not found on page"

        if field_type == "select":
            options = field_info.get("options", [])
            match = next((o for o in options if o.lower() == str(value).lower()), None)
            if not match:
                match = next(
                    (o for o in options if str(value).lower() in o.lower()), None
                )
            if match:
                await locator.select_option(label=match)
                return "filled", f"Selected option: {match}"
            return "needs_review", f"No matching option for '{value}'"

        if field_type in ("checkbox", "radio"):
            if str(value).lower() in ("true", "yes", "1"):
                await locator.check()
                return "filled", "Checked"
            return "skipped", "Value indicates unchecked"

        # text, email, tel, number, textarea, date
        await locator.fill(str(value))
        return "filled", "Filled"
    except Exception as e:
        logger.warning(f"Field fill failed for {selector}: {e}")
        return "failed", str(e)


async def auto_fill_government_form(
    portal_url: str,
    career_dna: dict,
    opportunity_id: str,
    timeout_ms: int = 30000,
) -> AutoFillResult:
    """
    Navigate to a real government portal form and fill it using the student's
    Career DNA. Never submits — always stops for human review before the final
    submit, since these are official government applications.
    """
    engine = FormIntelligenceEngine()
    result = AutoFillResult(success=False, portal_url=portal_url)

    try:
        async with async_playwright() as pw:
            browser = await pw.chromium.launch(headless=True, args=LAUNCH_ARGS)
            context = await browser.new_context(
                user_agent=(
                    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
                    "(KHTML, like Gecko) Chrome/124.0 Safari/537.36"
                ),
                viewport={"width": 1366, "height": 900},
            )
            page = await context.new_page()

            try:
                await page.goto(portal_url, timeout=timeout_ms, wait_until="domcontentloaded")
            except Exception as e:
                result.error = f"Could not load portal: {e}"
                await browser.close()
                return result

            raw_fields = await _extract_form_fields(page)
            result.fields_total = len(raw_fields)

            if not raw_fields:
                result.error = "No fillable form fields detected on this page. The form may be behind a login wall or rendered via JavaScript that needs interaction first."
                screenshot = await page.screenshot(full_page=True)
                result.screenshot_b64 = base64.b64encode(screenshot).decode()
                await browser.close()
                return result

            # Use the AI engine to determine values for each field
            fill_response = await engine.fill(
                form_fields=raw_fields,
                career_dna=career_dna,
                opportunity_id=opportunity_id,
            )
            filled_values = fill_response["filled_fields"]

            for f in raw_fields:
                fid = f["id"]
                value = filled_values.get(fid)
                label = f.get("label") or fid

                if value is None:
                    status = "needs_review" if f.get("required") else "skipped"
                    note = "No matching data in profile" if f.get("required") else ""
                    result.steps.append(
                        FillStep(field_id=fid, label=label, value=None, status=status, note=note)
                    )
                    if status == "needs_review":
                        result.requires_manual_review.append(label)
                    continue

                status, note = await _fill_field(page, f, value)
                result.steps.append(
                    FillStep(field_id=fid, label=label, value=value, status=status, note=note)
                )
                if status == "filled":
                    result.fields_filled += 1
                elif status in ("needs_review", "failed"):
                    result.requires_manual_review.append(label)

            screenshot = await page.screenshot(full_page=True)
            result.screenshot_b64 = base64.b64encode(screenshot).decode()
            result.success = result.fields_filled > 0
            await browser.close()

    except Exception as e:
        logger.error(f"Auto-fill failed for {portal_url}: {e}")
        result.error = str(e)

    return result
