import uuid
import pytest
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.security import verify_password
from app.db.database import check_db_health
from app.repositories.user_repository import UserRepository
from app.services.user_service import UserService
from app.schemas.user import UserCreate


@pytest.mark.asyncio
async def test_database_connectivity():
    """Verifies direct asyncpg connection to PostgreSQL."""
    is_healthy = await check_db_health()
    assert is_healthy is True


@pytest.mark.asyncio
async def test_user_creation_and_repository(db_session: AsyncSession):
    """Verifies User model persistence, hashing, and retrieval through repository layer."""
    unique_suffix = uuid.uuid4().hex[:8]
    test_email = f"test_{unique_suffix}@hums.audio"
    test_username = f"user_{unique_suffix}"

    user_repo = UserRepository(db_session)
    user_service = UserService(user_repo)

    user_in = UserCreate(
        email=test_email,
        username=test_username,
        password="SecurePassword123!",
        full_name="Hums Test Engineer",
    )

    user = await user_service.create_user(user_in)
    await db_session.commit()

    assert user.id is not None
    assert user.email == test_email
    assert user.username == test_username
    assert user.is_active is True
    assert verify_password("SecurePassword123!", user.hashed_password)

    # Retrieve through repository
    fetched = await user_repo.get_by_email(test_email)
    assert fetched is not None
    assert fetched.id == user.id

    # Clean up test user
    await user_repo.delete(user.id)
    await db_session.commit()
