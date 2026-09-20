from datetime import datetime, timedelta, timezone
import uuid
import pytest
from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.security import (
    create_access_token,
    create_password_reset_token,
    create_refresh_token,
    hash_password,
    hash_token_value,
    verify_password,
)
from app.db.models.user import PasswordResetToken, RefreshToken, User

settings = get_settings()


@pytest.mark.asyncio
class TestRegistration:
    async def test_successful_registration(self, async_client: AsyncClient, db_session: AsyncSession):
        """User can register with name, email, and password."""
        email = f"test_reg_{uuid.uuid4().hex[:8]}@example.com"
        response = await async_client.post(
            "/api/v1/auth/register",
            json={
                "name": "Test User",
                "email": email,
                "password": "strong-password-123",
            },
        )
        assert response.status_code == 201
        data = response.json()
        assert data["success"] is True
        auth_data = data["data"]
        assert "access_token" in auth_data
        assert "refresh_token" in auth_data
        assert auth_data["token_type"] == "Bearer"
        assert auth_data["expires_in"] == settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60

        user_info = auth_data["user"]
        assert user_info["email"] == email
        assert user_info["name"] == "Test User"
        assert "password" not in user_info
        assert "hashed_password" not in user_info

        # Verify in DB that password was hashed
        stmt = select(User).where(User.email == email)
        result = await db_session.execute(stmt)
        db_user = result.scalar_one_or_none()
        assert db_user is not None
        assert db_user.hashed_password != "strong-password-123"
        assert verify_password("strong-password-123", db_user.hashed_password) is True

    async def test_duplicate_email_registration(self, async_client: AsyncClient):
        """Registering an existing email returns 409 Conflict with EMAIL_ALREADY_EXISTS."""
        email = f"dup_{uuid.uuid4().hex[:8]}@example.com"
        # First registration
        res1 = await async_client.post(
            "/api/v1/auth/register",
            json={
                "name": "First User",
                "email": email,
                "password": "password12345",
            },
        )
        assert res1.status_code == 201

        # Second registration with same email (different case)
        res2 = await async_client.post(
            "/api/v1/auth/register",
            json={
                "name": "Second User",
                "email": email.upper(),
                "password": "password12345",
            },
        )
        assert res2.status_code == 409
        err = res2.json()
        assert err["success"] is False
        assert err["error"]["code"] == "EMAIL_ALREADY_EXISTS"

    async def test_invalid_email_registration(self, async_client: AsyncClient):
        """Invalid email formats return 422 Unprocessable Entity."""
        response = await async_client.post(
            "/api/v1/auth/register",
            json={
                "name": "Invalid Email",
                "email": "not-an-email",
                "password": "password12345",
            },
        )
        assert response.status_code == 422
        assert response.json()["success"] is False

    async def test_invalid_password_registration(self, async_client: AsyncClient):
        """Password shorter than 8 characters returns 422 Unprocessable Entity."""
        response = await async_client.post(
            "/api/v1/auth/register",
            json={
                "name": "Short Pw",
                "email": f"short_{uuid.uuid4().hex[:8]}@example.com",
                "password": "short",
            },
        )
        assert response.status_code == 422
        assert response.json()["success"] is False


@pytest.mark.asyncio
class TestLogin:
    async def test_successful_login(self, async_client: AsyncClient):
        """User can log in with correct email and password."""
        email = f"login_{uuid.uuid4().hex[:8]}@example.com"
        password = "valid-password-123"

        # Register first
        await async_client.post(
            "/api/v1/auth/register",
            json={"name": "Login User", "email": email, "password": password},
        )

        # Login
        response = await async_client.post(
            "/api/v1/auth/login",
            json={"email": email, "password": password},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        auth_data = data["data"]
        assert "access_token" in auth_data
        assert "refresh_token" in auth_data
        assert auth_data["user"]["email"] == email

    async def test_invalid_credentials_login(self, async_client: AsyncClient):
        """Invalid credentials return generic 401 INVALID_CREDENTIALS error."""
        # Non-existent user
        res1 = await async_client.post(
            "/api/v1/auth/login",
            json={"email": "nonexistent@example.com", "password": "wrongpassword"},
        )
        assert res1.status_code == 401
        assert res1.json()["error"]["code"] == "INVALID_CREDENTIALS"

        # Existing user, wrong password
        email = f"login_wrong_{uuid.uuid4().hex[:8]}@example.com"
        await async_client.post(
            "/api/v1/auth/register",
            json={"name": "User", "email": email, "password": "correctpassword"},
        )
        res2 = await async_client.post(
            "/api/v1/auth/login",
            json={"email": email, "password": "wrongpassword"},
        )
        assert res2.status_code == 401
        assert res2.json()["error"]["code"] == "INVALID_CREDENTIALS"
        # Error messages should be generic and identical
        assert res1.json()["error"]["message"] == res2.json()["error"]["message"]

    async def test_inactive_user_login(self, async_client: AsyncClient, db_session: AsyncSession):
        """Inactive users cannot log in."""
        email = f"inactive_{uuid.uuid4().hex[:8]}@example.com"
        password = "inactive-password"
        # Create inactive user directly in DB
        hashed_pw = hash_password(password)
        inactive_user = User(
            email=email,
            username=f"inact_{uuid.uuid4().hex[:6]}",
            hashed_password=hashed_pw,
            full_name="Inactive User",
            is_active=False,
        )
        db_session.add(inactive_user)
        await db_session.commit()

        response = await async_client.post(
            "/api/v1/auth/login",
            json={"email": email, "password": password},
        )
        assert response.status_code == 403
        assert response.json()["error"]["code"] == "ACCOUNT_INACTIVE"


@pytest.mark.asyncio
class TestAccessTokenAndMe:
    async def test_get_me_with_valid_token(self, async_client: AsyncClient):
        """Authenticated user can fetch their own profile via GET /api/v1/auth/me."""
        email = f"me_{uuid.uuid4().hex[:8]}@example.com"
        reg_res = await async_client.post(
            "/api/v1/auth/register",
            json={"name": "Me User", "email": email, "password": "password12345"},
        )
        token = reg_res.json()["data"]["access_token"]

        response = await async_client.get(
            "/api/v1/auth/me",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert data["data"]["email"] == email
        assert data["data"]["name"] == "Me User"

    async def test_get_me_unauthenticated(self, async_client: AsyncClient):
        """Request without token returns 401 UNAUTHORIZED."""
        response = await async_client.get("/api/v1/auth/me")
        assert response.status_code == 401
        assert response.json()["error"]["code"] == "UNAUTHORIZED"

    async def test_get_me_with_expired_token(self, async_client: AsyncClient):
        """Expired access token returns 401 UNAUTHORIZED."""
        user_id = str(uuid.uuid4())
        expired_token = create_access_token(
            subject=user_id,
            expires_delta=timedelta(seconds=-10),
        )
        response = await async_client.get(
            "/api/v1/auth/me",
            headers={"Authorization": f"Bearer {expired_token}"},
        )
        assert response.status_code == 401
        assert response.json()["error"]["code"] == "UNAUTHORIZED"

    async def test_get_me_with_invalid_token(self, async_client: AsyncClient):
        """Malformed or wrong secret JWT returns 401 UNAUTHORIZED."""
        response = await async_client.get(
            "/api/v1/auth/me",
            headers={"Authorization": "Bearer invalid.jwt.token"},
        )
        assert response.status_code == 401
        assert response.json()["error"]["code"] == "UNAUTHORIZED"


@pytest.mark.asyncio
class TestRefreshToken:
    async def test_refresh_token_rotation(self, async_client: AsyncClient, db_session: AsyncSession):
        """Token refresh issues a new access token and rotates the refresh token."""
        email = f"refresh_{uuid.uuid4().hex[:8]}@example.com"
        reg_res = await async_client.post(
            "/api/v1/auth/register",
            json={"name": "Refresh User", "email": email, "password": "password12345"},
        )
        tokens = reg_res.json()["data"]
        old_refresh_token = tokens["refresh_token"]

        # Perform refresh
        ref_res = await async_client.post(
            "/api/v1/auth/refresh",
            json={"refresh_token": old_refresh_token},
        )
        assert ref_res.status_code == 200
        new_tokens = ref_res.json()["data"]
        assert "access_token" in new_tokens
        assert "refresh_token" in new_tokens
        new_refresh_token = new_tokens["refresh_token"]
        assert new_refresh_token != old_refresh_token

        # Verify old refresh token is now revoked in database
        old_hash = hash_token_value(old_refresh_token)
        stmt = select(RefreshToken).where(RefreshToken.token_hash == old_hash)
        result = await db_session.execute(stmt)
        db_old_token = result.scalar_one_or_none()
        assert db_old_token is not None
        assert db_old_token.is_revoked is True
        assert db_old_token.revoked_at is not None

        # Trying to reuse old refresh token must be rejected
        reuse_res = await async_client.post(
            "/api/v1/auth/refresh",
            json={"refresh_token": old_refresh_token},
        )
        assert reuse_res.status_code == 401
        assert reuse_res.json()["error"]["code"] == "REFRESH_TOKEN_REVOKED"

    async def test_expired_refresh_token(self, async_client: AsyncClient, db_session: AsyncSession):
        """Expired refresh token is rejected with REFRESH_TOKEN_EXPIRED."""
        email = f"exp_ref_{uuid.uuid4().hex[:8]}@example.com"
        reg_res = await async_client.post(
            "/api/v1/auth/register",
            json={"name": "Exp User", "email": email, "password": "password12345"},
        )
        user_id = uuid.UUID(reg_res.json()["data"]["user"]["id"])

        # Manually create an expired refresh token in DB
        expired_jwt = create_refresh_token(subject=str(user_id), expires_delta=timedelta(seconds=-10))
        token_hash = hash_token_value(expired_jwt)
        expired_token_record = RefreshToken(
            user_id=user_id,
            token_hash=token_hash,
            expires_at=datetime.now(timezone.utc) - timedelta(seconds=10),
            is_revoked=False,
        )
        db_session.add(expired_token_record)
        await db_session.commit()

        ref_res = await async_client.post(
            "/api/v1/auth/refresh",
            json={"refresh_token": expired_jwt},
        )
        assert ref_res.status_code == 401
        assert ref_res.json()["error"]["code"] == "REFRESH_TOKEN_EXPIRED"

    async def test_invalid_refresh_token(self, async_client: AsyncClient):
        """Invalid or unknown refresh token is rejected."""
        ref_res = await async_client.post(
            "/api/v1/auth/refresh",
            json={"refresh_token": "completely-invalid-refresh-token"},
        )
        assert ref_res.status_code == 401
        assert ref_res.json()["error"]["code"] == "INVALID_REFRESH_TOKEN"


@pytest.mark.asyncio
class TestLogout:
    async def test_logout_revokes_refresh_token(self, async_client: AsyncClient):
        """Logging out revokes the refresh token so it cannot be used again."""
        email = f"logout_{uuid.uuid4().hex[:8]}@example.com"
        reg_res = await async_client.post(
            "/api/v1/auth/register",
            json={"name": "Logout User", "email": email, "password": "password12345"},
        )
        tokens = reg_res.json()["data"]
        refresh_token = tokens["refresh_token"]

        # Logout
        logout_res = await async_client.post(
            "/api/v1/auth/logout",
            json={"refresh_token": refresh_token},
        )
        assert logout_res.status_code == 200
        assert logout_res.json()["success"] is True

        # Refresh must now fail
        ref_res = await async_client.post(
            "/api/v1/auth/refresh",
            json={"refresh_token": refresh_token},
        )
        assert ref_res.status_code == 401
        assert ref_res.json()["error"]["code"] == "REFRESH_TOKEN_REVOKED"


@pytest.mark.asyncio
class TestPasswordReset:
    async def test_forgot_password_generic_response(self, async_client: AsyncClient):
        """Requesting password reset returns identical generic response for existing and non-existing accounts."""
        # Non-existing email
        res1 = await async_client.post(
            "/api/v1/auth/forgot-password",
            json={"email": "nonexistent_reset@example.com"},
        )
        assert res1.status_code == 200
        assert res1.json()["success"] is True

        # Existing email
        email = f"reset_gen_{uuid.uuid4().hex[:8]}@example.com"
        await async_client.post(
            "/api/v1/auth/register",
            json={"name": "Reset User", "email": email, "password": "password12345"},
        )
        res2 = await async_client.post(
            "/api/v1/auth/forgot-password",
            json={"email": email},
        )
        assert res2.status_code == 200
        assert res2.json()["data"]["message"] == res1.json()["data"]["message"]

    async def test_successful_password_reset_flow(
        self, async_client: AsyncClient, db_session: AsyncSession
    ):
        """Valid reset token resets the password and revokes existing refresh tokens."""
        email = f"reset_flow_{uuid.uuid4().hex[:8]}@example.com"
        reg_res = await async_client.post(
            "/api/v1/auth/register",
            json={"name": "Reset Flow", "email": email, "password": "old-password-123"},
        )
        old_refresh_token = reg_res.json()["data"]["refresh_token"]

        # Request reset
        await async_client.post(
            "/api/v1/auth/forgot-password",
            json={"email": email},
        )

        # Retrieve the generated token from the DB
        stmt = select(User).where(User.email == email)
        result = await db_session.execute(stmt)
        user = result.scalar_one()

        token_stmt = select(PasswordResetToken).where(
            PasswordResetToken.user_id == user.id,
            PasswordResetToken.used_at.is_(None),
        )
        token_res = await db_session.execute(token_stmt)
        reset_token_record = token_res.scalar_one()

        # Generate a test raw token and update token_hash to match for testing
        test_raw_token = f"valid-test-reset-token-{uuid.uuid4().hex}"
        reset_token_record.token_hash = hash_token_value(test_raw_token)
        await db_session.commit()

        # Submit password reset
        new_password = "new-strong-password-456"
        reset_res = await async_client.post(
            "/api/v1/auth/reset-password",
            json={
                "token": test_raw_token,
                "new_password": new_password,
            },
        )
        assert reset_res.status_code == 200
        assert reset_res.json()["success"] is True

        # Verify login works with new password
        login_new = await async_client.post(
            "/api/v1/auth/login",
            json={"email": email, "password": new_password},
        )
        assert login_new.status_code == 200

        # Verify old password fails
        login_old = await async_client.post(
            "/api/v1/auth/login",
            json={"email": email, "password": "old-password-123"},
        )
        assert login_old.status_code == 401

        # Verify prior refresh session was revoked
        ref_res = await async_client.post(
            "/api/v1/auth/refresh",
            json={"refresh_token": old_refresh_token},
        )
        assert ref_res.status_code == 401

        # Reusing the reset token must fail with RESET_TOKEN_USED
        reuse_res = await async_client.post(
            "/api/v1/auth/reset-password",
            json={
                "token": test_raw_token,
                "new_password": "yet-another-password",
            },
        )
        assert reuse_res.status_code == 400
        assert reuse_res.json()["error"]["code"] == "RESET_TOKEN_USED"

    async def test_expired_reset_token(
        self, async_client: AsyncClient, db_session: AsyncSession
    ):
        """Expired password reset token is rejected with RESET_TOKEN_EXPIRED."""
        email = f"expired_rst_{uuid.uuid4().hex[:8]}@example.com"
        reg_res = await async_client.post(
            "/api/v1/auth/register",
            json={"name": "Exp Reset", "email": email, "password": "password12345"},
        )
        user_id = uuid.UUID(reg_res.json()["data"]["user"]["id"])

        raw_token = f"expired-token-{uuid.uuid4().hex}"
        expired_record = PasswordResetToken(
            user_id=user_id,
            token_hash=hash_token_value(raw_token),
            expires_at=datetime.now(timezone.utc) - timedelta(minutes=5),
        )
        db_session.add(expired_record)
        await db_session.commit()

        reset_res = await async_client.post(
            "/api/v1/auth/reset-password",
            json={"token": raw_token, "new_password": "brand-new-password-123"},
        )
        assert reset_res.status_code == 400
        assert reset_res.json()["error"]["code"] == "RESET_TOKEN_EXPIRED"
