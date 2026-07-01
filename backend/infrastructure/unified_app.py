"""
FillFormAI - Unified deploy entrypoint.

Railway (and most simple hosts) charge per service, and a non-technical user
managing 10 separate microservice deployments by hand is a recipe for a
broken stack. All 10 services share the same Postgres database and have no
real need to run as separate processes for a deploy of this size, so this
module merges every service's FastAPI routes into a single app that can be
deployed as ONE Railway web service.

Locally / in docker-compose, the services still run as independent
processes (see docker-compose.yml) — this file is only used for the
single-service production deploy.
"""

import logging
import pathlib

import asyncpg
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from backend.shared.config.settings import settings

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="FillFormAI - Unified API", version="1.0.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Each service module below defines routes with the full "/api/v1/<service>/..."
# prefix already baked in (see backend/infrastructure/docker/nginx.conf for the
# matching prefixes), so we simply graft each one's routes onto this app
# rather than mounting (mounting would require routes to be defined relative
# to the mount point, which they aren't).
from backend.services.auth_service.main import app as _auth  # noqa: E402
from backend.services.profile_service.main import app as _profile  # noqa: E402
from backend.services.opportunity_service.main import app as _opportunity  # noqa: E402
from backend.services.application_service.main import app as _application  # noqa: E402
from backend.services.document_service.main import app as _document  # noqa: E402
from backend.services.agent_service.main import app as _agent  # noqa: E402
from backend.services.notification_service.main import app as _notification  # noqa: E402
from backend.services.ai_service.main import app as _ai  # noqa: E402
from backend.services.payment_service.main import app as _payment  # noqa: E402
from backend.services.scraper_service.main import app as _scraper  # noqa: E402

_SUB_APPS = [
    _auth,
    _profile,
    _opportunity,
    _application,
    _document,
    _agent,
    _notification,
    _ai,
    _payment,
    _scraper,
]

for _sub in _SUB_APPS:
    for _route in _sub.router.routes:
        app.router.routes.append(_route)


@app.get("/health")
async def health():
    return {
        "status": "ok",
        "service": "fillformai-unified",
        "merged_services": len(_SUB_APPS),
    }


@app.get("/")
async def root():
    return {"service": "FillFormAI API", "docs": "/docs", "health": "/health"}


# ── One-time schema bootstrap ────────────────────────────────────────────────
# Reuses the same init.sql that docker-compose mounts into Postgres on first
# boot. Every statement in it is idempotent (CREATE TABLE IF NOT EXISTS,
# ALTER TABLE ... ADD COLUMN IF NOT EXISTS, CREATE INDEX IF NOT EXISTS) except
# the final seed INSERTs, which we only run if the opportunities table is
# still empty so a redeploy/restart never duplicates seed rows.
_INIT_SQL_PATH = pathlib.Path(__file__).resolve().parent / "docker" / "init.sql"
_SEED_MARKER = "-- ── Seed Sample Opportunities"


@app.on_event("startup")
async def bootstrap_schema():
    raw_url = settings.DATABASE_URL.replace("postgresql+asyncpg://", "postgresql://")
    conn = await asyncpg.connect(raw_url)
    try:
        sql_text = _INIT_SQL_PATH.read_text()
        schema_sql, _, seed_sql = sql_text.partition(_SEED_MARKER)
        await conn.execute(schema_sql)
        count = await conn.fetchval("SELECT COUNT(*) FROM opportunities")
        if count == 0 and seed_sql:
            await conn.execute(_SEED_MARKER + seed_sql)
            logger.info("Seeded sample opportunities/agents (first boot)")
        logger.info("Schema bootstrap complete")
    except Exception:
        logger.exception("Schema bootstrap failed")
    finally:
        await conn.close()

    # init.sql only covers the tables each service's own docker-compose
    # bootstrap historically created; ORM-only tables declared purely in
    # Python (e.g. auth_service's RefreshToken -> "refresh_tokens", which has
    # no entry in init.sql at all) never get created by the block above.
    # Base.metadata accumulates every model class from every service we've
    # imported above, so create_all here catches anything init.sql missed.
    from backend.shared.database import Base, engine  # noqa: E402

    async with engine.begin() as db_conn:
        await db_conn.run_sync(Base.metadata.create_all)
    logger.info(
        "ORM metadata create_all complete (covers tables init.sql doesn't define)"
    )


# ── Background jobs ───────────────────────────────────────────────────────────
# scraper_service and notification_service each normally run their own
# APScheduler instance inside their own FastAPI lifespan. Since we only
# grafted their *routes* onto this app (not their lifespans), we start both
# schedulers here so the live-scraping (every 6h) and deadline-reminder
# (daily 9 AM IST) jobs still run in the single merged deployment.
from apscheduler.schedulers.asyncio import AsyncIOScheduler  # noqa: E402
from backend.services.scraper_service.main import run_all_scrapers  # noqa: E402
from backend.services.notification_service.expiry_scheduler import (  # noqa: E402
    setup_expiry_scheduler,
)
from backend.shared.database import get_db  # noqa: E402

_scraper_scheduler: AsyncIOScheduler | None = None
_expiry_scheduler: AsyncIOScheduler | None = None


@app.on_event("startup")
async def start_background_jobs():
    global _scraper_scheduler, _expiry_scheduler
    _scraper_scheduler = AsyncIOScheduler(timezone="Asia/Kolkata")
    _scraper_scheduler.add_job(
        run_all_scrapers, "interval", hours=6, id="scrape_all_portals"
    )
    _scraper_scheduler.start()

    _expiry_scheduler = setup_expiry_scheduler(app, get_db)
    _expiry_scheduler.start()

    logger.info(
        "Background jobs started: scraper (6h), deadline reminders (daily 9 AM IST)"
    )


@app.on_event("shutdown")
async def stop_background_jobs():
    if _scraper_scheduler:
        _scraper_scheduler.shutdown(wait=False)
    if _expiry_scheduler:
        _expiry_scheduler.shutdown(wait=False)
