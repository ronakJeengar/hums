import io
import uuid
import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession
from pydantic import ValidationError

from app.core.config import Settings, get_settings
from app.core.security import create_access_token
from app.db.models.audio import Track
from app.db.models.user import User

settings = get_settings()


class TestSecurityHeaders:
    """Verifies defensive HTTP response headers on API endpoints."""

    async def test_security_headers_present(self, async_client: AsyncClient):
        response = await async_client.get("/health")
        assert response.status_code == 200
        headers = response.headers

        assert headers.get("X-Content-Type-Options") == "nosniff"
        assert headers.get("X-Frame-Options") == "DENY"
        assert headers.get("X-XSS-Protection") == "1; mode=block"
        assert headers.get("Referrer-Policy") == "strict-origin-when-cross-origin"
        assert "camera=()" in headers.get("Permissions-Policy", "")


class TestConfigSecurityValidation:
    """Verifies startup guardrails prevent unsafe production deployments."""

    def test_production_rejects_weak_secret_key(self):
        with pytest.raises(ValidationError, match=r"SECRET_KEY must be securely configured"):
            Settings(
                APP_ENV="production",
                SECRET_KEY="short-insecure-secret",
                DATABASE_URL="postgresql+asyncpg://u:p@localhost/db",
                REDIS_URL="redis://localhost:6379/0",
                CORS_ORIGINS=["https://hums.app"],
                DEBUG=False,
            )

    def test_production_rejects_debug_mode(self):
        with pytest.raises(ValidationError, match=r"DEBUG must be False"):
            Settings(
                APP_ENV="production",
                SECRET_KEY="a" * 64,
                DATABASE_URL="postgresql+asyncpg://u:p@localhost/db",
                REDIS_URL="redis://localhost:6379/0",
                CORS_ORIGINS=["https://hums.app"],
                DEBUG=True,
            )

    def test_production_rejects_wildcard_cors(self):
        with pytest.raises(ValidationError, match=r"Wildcard"):
            Settings(
                APP_ENV="production",
                SECRET_KEY="a" * 64,
                DATABASE_URL="postgresql+asyncpg://u:p@localhost/db",
                REDIS_URL="redis://localhost:6379/0",
                CORS_ORIGINS=["*"],
                DEBUG=False,
            )


class TestInputBoundsAndDosProtection:
    """Verifies length bounds on user inputs to prevent CPU and memory exhaustion."""

    async def test_login_rejects_pathological_password_length(self, async_client: AsyncClient):
        # 200 character password exceeds 128 character max bound
        long_password = "A" * 200
        response = await async_client.post(
            "/api/v1/auth/login",
            json={"email": "attacker@example.com", "password": long_password},
        )
        assert response.status_code == 422

    async def test_audio_upload_rejects_excessive_metadata_length(self, async_client: AsyncClient):
        # Authenticate test user
        email = f"sec_audio_{uuid.uuid4().hex[:8]}@example.com"
        reg = await async_client.post(
            "/api/v1/auth/register",
            json={"name": "Sec Audio", "email": email, "password": "password123"},
        )
        token = reg.json()["data"]["access_token"]
        headers = {"Authorization": f"Bearer {token}"}

        # Attempt upload with 300 char title (max is 255)
        fake_audio = io.BytesIO(b"ID3" + b"\x00" * 200)
        response = await async_client.post(
            "/api/v1/audio/upload",
            headers=headers,
            data={
                "title": "A" * 300,
                "genre": "Rock",
            },
            files={"file": ("track.mp3", fake_audio, "audio/mpeg")},
        )
        assert response.status_code == 400
        assert response.json().get("error", {}).get("code") == "INVALID_TRACK_DATA"

    async def test_upload_file_bounded_oversized_rejection(self, async_client: AsyncClient):
        email = f"oversize_{uuid.uuid4().hex[:8]}@example.com"
        reg = await async_client.post(
            "/api/v1/auth/register",
            json={"name": "Oversize Test", "email": email, "password": "password123"},
        )
        token = reg.json()["data"]["access_token"]
        headers = {"Authorization": f"Bearer {token}"}

        # Create a payload stream exceeding MAX_AUDIO_SIZE_BYTES (temporarily mock MAX_AUDIO_SIZE_BYTES or test avatar limit)
        # In profile avatar upload, max size is MAX_IMAGE_SIZE_BYTES (10MB)
        # We can test by mocking MAX_IMAGE_SIZE_BYTES or passing 11MB file to avatar upload
        # Or testing read_upload_file_bounded directly
        from fastapi import UploadFile
        from app.utils.upload import read_upload_file_bounded
        from app.core.errors import BadRequestError

        fake_upload = UploadFile(
            file=io.BytesIO(b"X" * 2000),
            filename="test.bin",
            headers={"content-type": "application/octet-stream"},
        )
        with pytest.raises(BadRequestError, match="Uploaded file exceeds maximum allowed size"):
            await read_upload_file_bounded(fake_upload, max_bytes=1000)

    async def test_playlist_reorder_rejects_excessive_track_count(self, async_client: AsyncClient):
        email = f"reorder_{uuid.uuid4().hex[:8]}@example.com"
        reg = await async_client.post(
            "/api/v1/auth/register",
            json={"name": "Reorder Test", "email": email, "password": "password123"},
        )
        token = reg.json()["data"]["access_token"]
        headers = {"Authorization": f"Bearer {token}"}

        pl = await async_client.post(
            "/api/v1/playlists",
            headers=headers,
            json={"name": "Reorder Test Playlist"},
        )
        pl_id = pl.json()["data"]["id"]

        # Attempt to reorder with 501 track IDs (max bound is 500)
        excessive_track_ids = [str(uuid.uuid4()) for _ in range(501)]
        res = await async_client.patch(
            f"/api/v1/playlists/{pl_id}/tracks/reorder",
            headers=headers,
            json={"track_ids": excessive_track_ids},
        )
        assert res.status_code == 422



class TestRateLimiting:
    """Verifies Redis-backed sliding/fixed-window rate limiting and Retry-After headers."""

    async def test_rate_limiter_enforces_limit_and_returns_429(self, async_client: AsyncClient):
        # Temporarily enable rate limiting for this test
        original_rate_limit = settings.RATE_LIMIT_ENABLED
        settings.RATE_LIMIT_ENABLED = True
        try:
            # POST /auth/forgot-password has a 5 req/min rate limit
            # Send 6 rapid requests
            hit_429 = False
            for i in range(7):
                res = await async_client.post(
                    "/api/v1/auth/forgot-password",
                    json={"email": f"rl_test_{uuid.uuid4().hex[:6]}@example.com"},
                )
                if res.status_code == 429:
                    hit_429 = True
                    assert "Retry-After" in res.headers
                    body = res.json()
                    assert body.get("error", {}).get("code") == "RATE_LIMIT_EXCEEDED"
                    break

            assert hit_429, "Rate limiter should have returned 429 after exceeding limit"
        finally:
            settings.RATE_LIMIT_ENABLED = original_rate_limit


class TestAuthorizationAndTokenSecurity:
    """Verifies cryptographic signature validation and IDOR prevention."""

    async def test_tampered_jwt_token_is_rejected(self, async_client: AsyncClient):
        email = f"tamper_{uuid.uuid4().hex[:8]}@example.com"
        reg = await async_client.post(
            "/api/v1/auth/register",
            json={"name": "Tamper Test", "email": email, "password": "password123"},
        )
        token = reg.json()["data"]["access_token"]

        # Tamper with the token signature (flip last few characters)
        tampered_token = token[:-4] + ("AAAA" if not token.endswith("AAAA") else "BBBB")
        response = await async_client.get(
            "/api/v1/auth/me",
            headers={"Authorization": f"Bearer {tampered_token}"},
        )
        assert response.status_code == 401
        assert response.json().get("error", {}).get("code") in ("UNAUTHORIZED", "INVALID_TOKEN")

    async def test_playlist_idor_cross_user_isolation(self, async_client: AsyncClient):
        # Create User A and User B
        res_a = await async_client.post(
            "/api/v1/auth/register",
            json={"name": "User A", "email": f"usera_{uuid.uuid4().hex[:8]}@example.com", "password": "password123"},
        )
        token_a = res_a.json()["data"]["access_token"]

        res_b = await async_client.post(
            "/api/v1/auth/register",
            json={"name": "User B", "email": f"userb_{uuid.uuid4().hex[:8]}@example.com", "password": "password123"},
        )
        token_b = res_b.json()["data"]["access_token"]

        # User A creates a private playlist
        pl_res = await async_client.post(
            "/api/v1/playlists",
            headers={"Authorization": f"Bearer {token_a}"},
            json={"name": "User A Private Playlist", "description": "Secret"},
        )
        playlist_id = pl_res.json()["data"]["id"]

        # User B attempts to delete User A's playlist (IDOR attack)
        del_res = await async_client.delete(
            f"/api/v1/playlists/{playlist_id}",
            headers={"Authorization": f"Bearer {token_b}"},
        )
        assert del_res.status_code in (403, 404)

        # User B attempts to update User A's playlist
        update_res = await async_client.patch(
            f"/api/v1/playlists/{playlist_id}",
            headers={"Authorization": f"Bearer {token_b}"},
            json={"name": "Hijacked Name"},
        )
        assert update_res.status_code in (403, 404)

    async def test_cannot_add_failed_track_to_playlist(
        self, async_client: AsyncClient, db_session: AsyncSession
    ):
        # Register user and create playlist
        res = await async_client.post(
            "/api/v1/auth/register",
            json={"name": "Track Test", "email": f"tr_{uuid.uuid4().hex[:8]}@example.com", "password": "password123"},
        )
        user_data = res.json()["data"]
        token = user_data["access_token"]
        user_id = uuid.UUID(user_data["user"]["id"])

        pl_res = await async_client.post(
            "/api/v1/playlists",
            headers={"Authorization": f"Bearer {token}"},
            json={"name": "Corrupt Track Test Playlist"},
        )
        playlist_id = pl_res.json()["data"]["id"]

        # Seed a track with FAILED status directly in DB
        failed_track = Track(
            id=uuid.uuid4(),
            owner_id=user_id,
            title="Corrupted Audio Track",
            status="FAILED",
        )
        db_session.add(failed_track)
        await db_session.commit()

        # Attempt to add the failed track to the playlist
        add_res = await async_client.post(
            f"/api/v1/playlists/{playlist_id}/tracks",
            headers={"Authorization": f"Bearer {token}"},
            json={"track_id": str(failed_track.id)},
        )
        assert add_res.status_code == 400
        assert add_res.json().get("error", {}).get("code") == "TRACK_FAILED"
