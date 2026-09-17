from typing import Optional
import uuid
from app.core.errors import ConflictError, NotFoundError
from app.core.security import hash_password
from app.db.models.user import User
from app.repositories.user_repository import UserRepository
from app.schemas.user import UserCreate


class UserService:
    """Business logic for User account management."""

    def __init__(self, user_repo: UserRepository):
        self.user_repo = user_repo

    async def get_user_by_id(self, user_id: uuid.UUID) -> User:
        user = await self.user_repo.get_by_id(user_id)
        if not user:
            raise NotFoundError(f"User with ID {user_id} does not exist")
        return user

    async def get_user_by_email(self, email: str) -> Optional[User]:
        return await self.user_repo.get_by_email(email)

    async def create_user(self, user_in: UserCreate) -> User:
        existing_email = await self.user_repo.get_by_email(user_in.email)
        if existing_email:
            raise ConflictError("An account with this email address already exists")

        existing_username = await self.user_repo.get_by_username(user_in.username)
        if existing_username:
            raise ConflictError("Username is already taken")

        hashed_pw = hash_password(user_in.password)
        user = await self.user_repo.create(
            email=user_in.email.lower().strip(),
            username=user_in.username.strip(),
            hashed_password=hashed_pw,
            full_name=user_in.full_name,
            is_active=True,
            is_verified=False,
        )
        return user
