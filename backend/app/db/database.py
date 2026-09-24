from typing import AsyncGenerator
from sqlalchemy.ext.asyncio import (
    AsyncEngine,
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy import text
from app.core.config import get_settings
import logging

logger = logging.getLogger("hums.database")
settings = get_settings()

from sqlalchemy.pool import NullPool

# Asynchronous SQLAlchemy Engine
is_testing = settings.APP_ENV == "testing"
engine: AsyncEngine = create_async_engine(
    settings.DATABASE_URL,
    echo=settings.DEBUG,
    pool_pre_ping=True,
    poolclass=NullPool if is_testing else None,
    **(
        {}
        if is_testing
        else {
            "pool_size": 20,
            "max_overflow": 10,
            "pool_timeout": 30,
            "pool_recycle": 1800,
        }
    ),
)

# Asynchronous Session Factory
AsyncSessionLocal = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autocommit=False,
    autoflush=False,
)


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """Dependency generator yielding an isolated async database session."""
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()


async def check_db_health() -> bool:
    """Executes a simple SELECT 1 query to verify database connectivity."""
    try:
        async with AsyncSessionLocal() as session:
            result = await session.execute(text("SELECT 1"))
            return result.scalar() == 1
    except Exception as exc:
        logger.error(f"Database health check failed: {exc}")
        return False
