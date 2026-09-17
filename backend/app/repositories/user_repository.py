from typing import Optional
import uuid
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.db.models.user import User, RefreshToken
from app.repositories.base import BaseRepository


class UserRepository(BaseRepository[User]):
    """Repository managing User entity persistence."""

    def __init__(self, session: AsyncSession):
        super().__init__(User, session)

    async def get_by_email(self, email: str) -> Optional[User]:
        """Looks up a user by case-insensitive normalized email."""
        stmt = select(User).where(User.email == email.lower().strip())
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_username(self, username: str) -> Optional[User]:
        """Looks up a user by username."""
        stmt = select(User).where(User.username == username.strip())
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()


class RefreshTokenRepository(BaseRepository[RefreshToken]):
    """Repository managing RefreshToken persistence."""

    def __init__(self, session: AsyncSession):
        super().__init__(RefreshToken, session)

    async def get_by_token_hash(self, token_hash: str) -> Optional[RefreshToken]:
        """Finds token by SHA-256 hash."""
        stmt = select(RefreshToken).where(RefreshToken.token_hash == token_hash)
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()
