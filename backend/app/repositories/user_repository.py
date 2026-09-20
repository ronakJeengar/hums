from datetime import datetime, timezone
from typing import Optional
import uuid
from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession
from app.db.models.user import User, RefreshToken, PasswordResetToken
from app.repositories.base import BaseRepository


class UserRepository(BaseRepository[User]):
    """Repository managing User entity persistence."""

    def __init__(self, session: AsyncSession):
        super().__init__(User, session)

    async def get_by_email(self, email: str) -> Optional[User]:
        """Looks up a user by case-insensitive normalized email."""
        stmt = select(User).where(func.lower(User.email) == email.lower().strip())
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_username(self, username: str) -> Optional[User]:
        """Looks up a user by username."""
        stmt = select(User).where(User.username == username.strip())
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def update_last_login(self, user: User) -> User:
        """Updates user's last login timestamp."""
        user.last_login_at = datetime.now(timezone.utc)
        await self.session.flush()
        await self.session.refresh(user)
        return user

    async def update_password(self, user: User, new_hashed_password: str) -> User:
        """Updates user's hashed password."""
        user.hashed_password = new_hashed_password
        await self.session.flush()
        await self.session.refresh(user)
        return user


class RefreshTokenRepository(BaseRepository[RefreshToken]):
    """Repository managing RefreshToken persistence."""

    def __init__(self, session: AsyncSession):
        super().__init__(RefreshToken, session)

    async def get_by_token_hash(self, token_hash: str) -> Optional[RefreshToken]:
        """Finds token by SHA-256 hash."""
        stmt = select(RefreshToken).where(RefreshToken.token_hash == token_hash)
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def revoke(self, token: RefreshToken) -> RefreshToken:
        """Revokes an active refresh token."""
        token.is_revoked = True
        token.revoked_at = datetime.now(timezone.utc)
        await self.session.flush()
        await self.session.refresh(token)
        return token

    async def revoke_all_for_user(self, user_id: uuid.UUID) -> int:
        """Revokes all active refresh tokens for a given user."""
        now = datetime.now(timezone.utc)
        stmt = (
            update(RefreshToken)
            .where(RefreshToken.user_id == user_id, RefreshToken.is_revoked == False)
            .values(is_revoked=True, revoked_at=now)
        )
        result = await self.session.execute(stmt)
        return result.rowcount


class PasswordResetTokenRepository(BaseRepository[PasswordResetToken]):
    """Repository managing PasswordResetToken persistence."""

    def __init__(self, session: AsyncSession):
        super().__init__(PasswordResetToken, session)

    async def get_by_token_hash(self, token_hash: str) -> Optional[PasswordResetToken]:
        """Finds password reset token by SHA-256 hash."""
        stmt = select(PasswordResetToken).where(PasswordResetToken.token_hash == token_hash)
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def mark_used(self, token: PasswordResetToken) -> PasswordResetToken:
        """Marks password reset token as used."""
        token.used_at = datetime.now(timezone.utc)
        await self.session.flush()
        await self.session.refresh(token)
        return token
