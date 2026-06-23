from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker
from sqlalchemy.orm import DeclarativeBase
from sqlalchemy import text
import redis.asyncio as aioredis
from motor.motor_asyncio import AsyncIOMotorClient
from functools import lru_cache
from typing import AsyncGenerator
import logging

from backend.shared.config.settings import settings

logger = logging.getLogger(__name__)


class Base(DeclarativeBase):
    pass


# ── PostgreSQL ────────────────────────────────────────────────────────────────
engine = create_async_engine(
    settings.DATABASE_URL,
    pool_size=20,
    max_overflow=40,
    pool_pre_ping=True,
    pool_recycle=3600,
    echo=settings.DEBUG,
)

AsyncSessionLocal = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,
)


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()


async def check_db_connection() -> bool:
    try:
        async with engine.connect() as conn:
            await conn.execute(text("SELECT 1"))
        return True
    except Exception as e:
        logger.error(f"DB connection failed: {e}")
        return False


# ── Redis ─────────────────────────────────────────────────────────────────────
@lru_cache
def get_redis_pool():
    return aioredis.ConnectionPool.from_url(
        settings.REDIS_URL,
        max_connections=50,
        decode_responses=True,
    )


async def get_redis() -> aioredis.Redis:
    return aioredis.Redis(connection_pool=get_redis_pool())


# ── MongoDB ───────────────────────────────────────────────────────────────────
_mongo_client: AsyncIOMotorClient | None = None


def get_mongo_client() -> AsyncIOMotorClient:
    global _mongo_client
    if _mongo_client is None:
        _mongo_client = AsyncIOMotorClient(settings.MONGO_URL)
    return _mongo_client


def get_mongo_db():
    return get_mongo_client()[settings.MONGO_DB]


# ── Init all connections ───────────────────────────────────────────────────────
async def init_db():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    logger.info("PostgreSQL tables created/verified")


async def close_db():
    await engine.dispose()
    if _mongo_client:
        _mongo_client.close()
    logger.info("Database connections closed")
