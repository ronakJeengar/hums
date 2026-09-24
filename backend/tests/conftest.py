import os
import pytest
from httpx import ASGITransport, AsyncClient
from typing import AsyncGenerator
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker
from sqlalchemy.pool import NullPool

os.environ["APP_ENV"] = "testing"
os.environ["RATE_LIMIT_ENABLED"] = "false"

from app.main import app
from app.core.config import get_settings

settings = get_settings()
settings.RATE_LIMIT_ENABLED = False

test_engine = create_async_engine(
    settings.DATABASE_URL,
    poolclass=NullPool,
    echo=False,
)

TestSessionLocal = async_sessionmaker(
    bind=test_engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autocommit=False,
    autoflush=False,
)


@pytest.fixture
async def db_session() -> AsyncGenerator[AsyncSession, None]:
    """Provides isolated async DB session using NullPool for testing."""
    async with TestSessionLocal() as session:
        try:
            yield session
        finally:
            await session.close()


@pytest.fixture
async def async_client() -> AsyncGenerator[AsyncClient, None]:
    """Provides an asynchronous HTTP test client bound to the FastAPI application."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        yield client
