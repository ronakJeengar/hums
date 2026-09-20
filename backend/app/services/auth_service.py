from datetime import datetime, timedelta, timezone
import secrets
from typing import Optional, Tuple
import uuid
from fastapi import status
import jwt

from app.core.config import get_settings
from app.core.errors import AuthenticationError, ConflictError, NotFoundError
from app.core.security import (
    create_access_token,
    create_password_reset_token,
    create_refresh_token,
    decode_token,
    hash_password,
    hash_token_value,
    verify_password,
)
from app.db.models.user import User
from app.repositories.user_repository import (
    PasswordResetTokenRepository,
    RefreshTokenRepository,
    UserRepository,
)
from app.schemas.user import RegisterRequest, TokenResponse, UserCreate, UserLogin

settings = get_settings()


class AuthService:
    """Business logic for authentication, tokens, and password reset."""

    def __init__(
        self,
        user_repo: UserRepository,
        refresh_token_repo: RefreshTokenRepository,
        password_reset_token_repo: PasswordResetTokenRepository,
    ):
        self.user_repo = user_repo
        self.refresh_token_repo = refresh_token_repo
        self.password_reset_token_repo = password_reset_token_repo

    async def register(
        self,
        user_in: RegisterRequest,
        client_ip: Optional[str] = None,
        user_agent: Optional[str] = None,
    ) -> Tuple[User, TokenResponse]:
        """Registers a new user, hashes password, and issues initial token pair."""
        normalized_email = user_in.email.lower().strip()
        existing_user = await self.user_repo.get_by_email(normalized_email)
        if existing_user:
            raise ConflictError(
                "An account with this email address already exists",
                code="EMAIL_ALREADY_EXISTS",
            )

        # Determine username: use provided or generate unique username from name
        username = user_in.username.strip() if user_in.username else None
        if username:
            existing_username = await self.user_repo.get_by_username(username)
            if existing_username:
                raise ConflictError("Username is already taken", code="USERNAME_TAKEN")
        else:
            base_slug = "".join(c for c in user_in.name.lower() if c.isalnum() or c == "_")[:30]
            if not base_slug:
                base_slug = "user"
            candidate = base_slug
            while await self.user_repo.get_by_username(candidate):
                candidate = f"{base_slug}_{secrets.token_hex(3)}"
            username = candidate

        hashed_pw = hash_password(user_in.password)
        user = await self.user_repo.create(
            email=normalized_email,
            username=username,
            hashed_password=hashed_pw,
            full_name=user_in.name.strip(),
            is_active=True,
            is_verified=False,
        )

        token_response = await self._issue_token_pair(
            user=user,
            client_ip=client_ip,
            user_agent=user_agent,
        )
        return user, token_response

    async def login(
        self,
        credentials: UserLogin,
        client_ip: Optional[str] = None,
        user_agent: Optional[str] = None,
    ) -> Tuple[User, TokenResponse]:
        """Authenticates user with email/password and issues token pair."""
        normalized_email = credentials.email.lower().strip()
        user = await self.user_repo.get_by_email(normalized_email)

        # Generic authentication failure: never reveal if email exists or password was wrong
        if not user or not verify_password(credentials.password, user.hashed_password):
            raise AuthenticationError(
                "Invalid email or password",
                code="INVALID_CREDENTIALS",
            )

        if not user.is_active:
            raise AuthenticationError(
                "Account is inactive",
                code="ACCOUNT_INACTIVE",
                status_code=status.HTTP_403_FORBIDDEN,
            )

        await self.user_repo.update_last_login(user)
        token_response = await self._issue_token_pair(
            user=user,
            client_ip=client_ip,
            user_agent=user_agent,
        )
        return user, token_response

    async def refresh_tokens(
        self,
        raw_refresh_token: str,
        client_ip: Optional[str] = None,
        user_agent: Optional[str] = None,
    ) -> TokenResponse:
        """
        Validates refresh token and performs token rotation.
        Revokes the presented refresh token and issues a new access/refresh token pair.
        """
        try:
            payload = decode_token(raw_refresh_token)
            if payload.get("type") != "refresh":
                raise AuthenticationError(
                    "Invalid token type. Expected refresh token.",
                    code="INVALID_REFRESH_TOKEN",
                )
            user_id_str = payload.get("sub")
            if not user_id_str:
                raise AuthenticationError("Malformed token claims", code="INVALID_REFRESH_TOKEN")
            user_id = uuid.UUID(user_id_str)
        except jwt.ExpiredSignatureError:
            raise AuthenticationError("Refresh token has expired", code="REFRESH_TOKEN_EXPIRED")
        except AuthenticationError:
            raise
        except Exception:
            raise AuthenticationError("Invalid refresh token", code="INVALID_REFRESH_TOKEN")

        token_hash = hash_token_value(raw_refresh_token)
        stored_token = await self.refresh_token_repo.get_by_token_hash(token_hash)
        if not stored_token:
            raise AuthenticationError("Invalid refresh token", code="INVALID_REFRESH_TOKEN")

        if stored_token.is_revoked or stored_token.revoked_at is not None:
            raise AuthenticationError("Refresh token has been revoked", code="REFRESH_TOKEN_REVOKED")

        now = datetime.now(timezone.utc)
        if stored_token.expires_at <= now:
            raise AuthenticationError("Refresh token has expired", code="REFRESH_TOKEN_EXPIRED")

        user = await self.user_repo.get_by_id(user_id)
        if not user or not user.is_active:
            raise AuthenticationError(
                "Account is inactive",
                code="ACCOUNT_INACTIVE",
                status_code=status.HTTP_403_FORBIDDEN,
            )

        # Revoke old refresh token (Token Rotation)
        await self.refresh_token_repo.revoke(stored_token)

        # Issue new token pair
        return await self._issue_token_pair(
            user=user,
            client_ip=client_ip,
            user_agent=user_agent,
        )

    async def logout(
        self,
        raw_refresh_token: Optional[str] = None,
        user_id: Optional[uuid.UUID] = None,
    ) -> None:
        """Invalidates/revokes the refresh token session."""
        if raw_refresh_token:
            token_hash = hash_token_value(raw_refresh_token)
            stored_token = await self.refresh_token_repo.get_by_token_hash(token_hash)
            if stored_token and not stored_token.is_revoked:
                await self.refresh_token_repo.revoke(stored_token)
        elif user_id:
            await self.refresh_token_repo.revoke_all_for_user(user_id)

    async def request_password_reset(self, email: str) -> Optional[str]:
        """
        Creates a single-use password reset token if account exists.
        Returns the raw token in development/testing, while API returns generic message.
        """
        normalized_email = email.lower().strip()
        user = await self.user_repo.get_by_email(normalized_email)

        # Prevent email enumeration: silently return if user does not exist or inactive
        if not user or not user.is_active:
            return None

        raw_token = create_password_reset_token()
        token_hash = hash_token_value(raw_token)
        expires_at = datetime.now(timezone.utc) + timedelta(
            minutes=settings.PASSWORD_RESET_TOKEN_EXPIRE_MINUTES
        )

        await self.password_reset_token_repo.create(
            user_id=user.id,
            token_hash=token_hash,
            expires_at=expires_at,
        )
        return raw_token

    async def reset_password(self, raw_token: str, new_password: str) -> None:
        """
        Validates reset token, updates user password, marks token used,
        and revokes all existing refresh sessions.
        """
        token_hash = hash_token_value(raw_token)
        reset_token = await self.password_reset_token_repo.get_by_token_hash(token_hash)

        if not reset_token:
            raise AuthenticationError(
                "Invalid or expired reset token",
                code="INVALID_RESET_TOKEN",
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        if reset_token.used_at is not None:
            raise AuthenticationError(
                "Reset token has already been used",
                code="RESET_TOKEN_USED",
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        now = datetime.now(timezone.utc)
        if reset_token.expires_at <= now:
            raise AuthenticationError(
                "Reset token has expired",
                code="RESET_TOKEN_EXPIRED",
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        user = await self.user_repo.get_by_id(reset_token.user_id)
        if not user or not user.is_active:
            raise AuthenticationError(
                "Account is inactive",
                code="ACCOUNT_INACTIVE",
                status_code=status.HTTP_403_FORBIDDEN,
            )

        # Update password
        new_hashed_pw = hash_password(new_password)
        await self.user_repo.update_password(user, new_hashed_pw)

        # Mark reset token as used (single-use)
        await self.password_reset_token_repo.mark_used(reset_token)

        # Invalidate all existing refresh tokens for security
        await self.refresh_token_repo.revoke_all_for_user(user.id)

    async def _issue_token_pair(
        self,
        user: User,
        client_ip: Optional[str] = None,
        user_agent: Optional[str] = None,
    ) -> TokenResponse:
        """Internal helper to create JWT access token and store hashed refresh token."""
        access_token = create_access_token(subject=str(user.id))
        raw_refresh_token = create_refresh_token(subject=str(user.id))

        token_hash = hash_token_value(raw_refresh_token)
        expires_at = datetime.now(timezone.utc) + timedelta(
            days=settings.REFRESH_TOKEN_EXPIRE_DAYS
        )

        await self.refresh_token_repo.create(
            user_id=user.id,
            token_hash=token_hash,
            device_info=user_agent,
            ip_address=client_ip,
            expires_at=expires_at,
        )

        return TokenResponse(
            access_token=access_token,
            refresh_token=raw_refresh_token,
            token_type="Bearer",
            expires_in=settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
        )
