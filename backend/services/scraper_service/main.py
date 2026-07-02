"""
FillFormAI - Scraper Service (port 8010)
Continuously discovers real scholarships, govt jobs, and exam notifications
from NSP, UP Scholarship, SSC, Railway, NCS, and state portals.

Runs on a schedule (every 6 hours) and on-demand via API.
New opportunities trigger notifications to matching users.
"""

import logging
from contextlib import asynccontextmanager
from datetime import datetime, timezone

from apscheduler.schedulers.asyncio import AsyncIOScheduler
from fastapi import FastAPI, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import select, text

from backend.shared.config.settings import settings
from backend.shared.database import init_db, close_db
from backend.shared.middleware.auth import get_current_admin
from backend.services.opportunity_service.models import Opportunity
from backend.services.scraper_service.scrapers.nsp import get_nsp_opportunities
from backend.services.scraper_service.scrapers.up_scholarship import (
    get_up_scholarship_opportunities,
)
from backend.services.scraper_service.scrapers.ssc_railway import (
    get_ssc_railway_opportunities,
)
from backend.services.scraper_service.scrapers.state_portals import (
    get_state_opportunities,
)

logger = logging.getLogger(__name__)

_scheduler: AsyncIOScheduler | None = None

SCRAPERS = {
    "nsp": get_nsp_opportunities,
    "up_scholarship": get_up_scholarship_opportunities,
    "ssc_railway": get_ssc_railway_opportunities,
    "state_portals": get_state_opportunities,
}


@asynccontextmanager
async def lifespan(app: FastAPI):
    global _scheduler
    await init_db()
    _scheduler = AsyncIOScheduler(timezone="Asia/Kolkata")
    _scheduler.add_job(
        run_all_scrapers,
        "interval",
        hours=6,
        id="scrape_all_portals",
        next_run_time=datetime.now(),
    )
    _scheduler.start()
    logger.info("Scraper service started — running every 6 hours")
    yield
    if _scheduler:
        _scheduler.shutdown(wait=False)
    await close_db()


app = FastAPI(title="FillFormAI - Scraper Service", version="1.0.0", lifespan=lifespan)
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

_last_run: dict = {}


async def _upsert_opportunity(db, opp: dict) -> bool:
    """Insert opportunity if new (matched by title + issuing_authority). Returns True if new."""
    existing = await db.scalar(
        select(Opportunity).where(
            Opportunity.title == opp["title"],
            Opportunity.issuing_authority == opp.get("issuing_authority"),
        )
    )
    now_iso = datetime.now(timezone.utc).isoformat()

    amount_int = None
    if opp.get("amount_max") is not None:
        amount_int = int(opp["amount_max"])
    elif opp.get("amount_min") is not None:
        amount_int = int(opp["amount_min"])

    eligibility_rules = opp.get("eligibility_rules", {})
    states_allowed = eligibility_rules.get("states_allowed", [])
    state_value = (
        states_allowed[0] if states_allowed and states_allowed != ["ALL"] else None
    )
    eligibility_summary = (
        opp.get("eligibility_summary")
        or [f"{k}: {v}" for k, v in eligibility_rules.items()][:5]
    )

    if existing:
        existing.deadline = opp.get("deadline")
        existing.amount_min = opp.get("amount_min")
        existing.amount_max = opp.get("amount_max")
        existing.eligibility_rules = eligibility_rules
        existing.status = opp.get("status", "active")
        existing.last_scraped_at = now_iso
        # Keep legacy raw-SQL-dependent columns (application_service, agent_service) in sync.
        existing.description = opp.get("short_description") or opp.get(
            "full_description"
        )
        existing.amount = amount_int
        existing.eligibility_criteria = eligibility_rules
        existing.state = state_value
        existing.source_url = opp.get("portal_url")
        existing.eligibility_summary = eligibility_summary
        existing.is_active = opp.get("status", "active") == "active"
        return False

    new_opp = Opportunity(
        title=opp["title"],
        short_description=opp.get("short_description"),
        full_description=opp.get("full_description"),
        category=opp["category"],
        subcategory=opp.get("subcategory"),
        issuing_authority=opp.get("issuing_authority"),
        portal_url=opp.get("portal_url"),
        deadline=opp.get("deadline"),
        amount_min=opp.get("amount_min"),
        amount_max=opp.get("amount_max"),
        currency=opp.get("currency", "INR"),
        status=opp.get("status", "active"),
        is_verified=opp.get("is_verified", False),
        verification_confidence=opp.get("verification_confidence", 0.5),
        eligibility_rules=eligibility_rules,
        documents_required=opp.get("documents_required", []),
        difficulty_score=opp.get("difficulty_score", 0.5),
        competition_score=opp.get("competition_score", 0.5),
        tags=opp.get("tags", []),
        source=opp.get("source"),
        last_scraped_at=now_iso,
        # Legacy columns kept in sync so application_service/agent_service's raw
        # SQL queries against the original simple schema see real data.
        description=opp.get("short_description") or opp.get("full_description"),
        amount=amount_int,
        eligibility_criteria=eligibility_rules,
        state=state_value,
        level=opp.get("subcategory"),
        source_url=opp.get("portal_url"),
        eligibility_summary=eligibility_summary,
        is_active=opp.get("status", "active") == "active",
    )
    db.add(new_opp)
    return True


async def _notify_matching_users(db, new_opportunities: list[Opportunity]):
    """Notify users whose profile state/category matches newly discovered opportunities."""
    if not new_opportunities:
        return
    try:
        for opp in new_opportunities[:10]:  # cap to avoid notification storms per run
            states = (opp.eligibility_rules or {}).get("states_allowed", ["ALL"])
            categories = (opp.eligibility_rules or {}).get("categories", [])

            where_parts = ["u.is_active = true"]
            params: dict = {}
            if states and "ALL" not in states:
                where_parts.append("u.state = ANY(:states)")
                params["states"] = states
            if categories:
                where_parts.append("u.category = ANY(:categories)")
                params["categories"] = categories

            where = " AND ".join(where_parts)
            rows = await db.execute(
                text(f"SELECT id, phone FROM users u WHERE {where} LIMIT 500"),
                params,
            )
            user_rows = rows.fetchall()

            for row in user_rows:
                db.add_notification = True  # marker, actual insert below

            if user_rows:
                # channel is NOT NULL with no column default; omitting it
                # (as this used to) made every one of these inserts fail
                # silently, so no opportunity-match notification was ever
                # actually created.
                values_sql = ", ".join(
                    f"(:uid_{i}, :title_{i}, :body_{i}, 'new_opportunity', 'in_app', NOW())"
                    for i in range(len(user_rows))
                )
                insert_params = {}
                for i, row in enumerate(user_rows):
                    insert_params[f"uid_{i}"] = row.id
                    insert_params[f"title_{i}"] = f"New: {opp.title[:80]}"
                    insert_params[f"body_{i}"] = (
                        f"A new opportunity matching your profile just opened: {opp.title}. "
                        f"Deadline: {opp.deadline}."
                    )
                await db.execute(
                    text(
                        f"INSERT INTO notifications (user_id, title, body, type, channel, created_at) "
                        f"VALUES {values_sql}"
                    ),
                    insert_params,
                )
        await db.commit()
    except Exception as e:
        logger.error(f"Notify matching users failed: {e}")
        # Without this, a failed statement here leaves the shared session's
        # transaction "aborted" for every later query on it -- including the
        # other 3 scrapers' upserts in the same run_all_scrapers() call --
        # so one bad notification silently broke every scraper that ran
        # after it.
        await db.rollback()


async def run_all_scrapers() -> dict:
    """Run all portal scrapers and upsert results into the database."""
    from backend.shared.database import AsyncSessionLocal

    summary = {}
    async with AsyncSessionLocal() as db:
        for name, scraper_fn in SCRAPERS.items():
            try:
                opportunities = await scraper_fn()
                new_count = 0
                new_opps = []
                for opp in opportunities:
                    is_new = await _upsert_opportunity(db, opp)
                    if is_new:
                        new_count += 1
                await db.commit()

                # Re-fetch newly created ones from this run for notification
                if new_count:
                    result = await db.execute(
                        select(Opportunity)
                        .where(
                            Opportunity.source.like(
                                f"%{opportunities[0].get('source', '')}%"
                            )
                        )
                        .order_by(Opportunity.created_at.desc())
                        .limit(new_count)
                    )
                    new_opps = result.scalars().all()
                    await _notify_matching_users(db, new_opps)

                summary[name] = {
                    "total_found": len(opportunities),
                    "new": new_count,
                    "status": "success",
                }
                logger.info(
                    f"Scraper '{name}': {len(opportunities)} found, {new_count} new"
                )
            except Exception as e:
                logger.error(f"Scraper '{name}' failed: {e}")
                summary[name] = {"status": "error", "error": str(e)}

        global _last_run
        _last_run = {
            "ran_at": datetime.now(timezone.utc).isoformat(),
            "summary": summary,
        }
    return summary


# ── Endpoints ──────────────────────────────────────────────────────────────────


@app.get("/health")
async def health():
    next_run = None
    if _scheduler:
        job = _scheduler.get_job("scrape_all_portals")
        if job:
            next_run = str(job.next_run_time)
    return {
        "status": "ok",
        "service": "scraper-service",
        "scheduler_running": _scheduler.running if _scheduler else False,
        "next_run": next_run,
        "last_run": _last_run,
    }


@app.post("/api/v1/scraper/run")
async def trigger_scrape(current_user=Depends(get_current_admin)):
    """Manually trigger all scrapers (admin only)."""
    summary = await run_all_scrapers()
    return {"triggered": True, "summary": summary}


@app.post("/api/v1/scraper/run/{source_name}")
async def trigger_single_scrape(
    source_name: str,
    current_user=Depends(get_current_admin),
):
    """Manually trigger a single scraper by name (admin only)."""
    if source_name not in SCRAPERS:
        raise HTTPException(
            404, f"Unknown scraper: {source_name}. Options: {list(SCRAPERS.keys())}"
        )

    from backend.shared.database import AsyncSessionLocal

    async with AsyncSessionLocal() as db:
        opportunities = await SCRAPERS[source_name]()
        new_count = 0
        for opp in opportunities:
            if await _upsert_opportunity(db, opp):
                new_count += 1
        await db.commit()

    return {"source": source_name, "total_found": len(opportunities), "new": new_count}


@app.get("/api/v1/scraper/sources")
async def list_sources():
    return {"sources": list(SCRAPERS.keys()), "last_run": _last_run}
