"""Tests for Playback Quality Selection, Audio Quality Tiers & Data Saver.

Verifies:
- Settings API: GET /api/v1/settings/playback returns defaults.
- Settings API: PUT /api/v1/settings/playback updates preferences with validation.
- Settings API: User isolation between accounts.
- Playback API: GET /api/v1/audio/tracks/{track_id}/playback?quality=... selects correct rendition.
- Playback API: Rendition fallback when preferred tier is absent.
- Download API: GET /api/v1/audio/tracks/{track_id}/download?quality=... selects correct rendition.
- Authorization: Unauthenticated callers rejected with 401, private tracks with 403.
"""

import uuid
import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models.audio import AudioRendition, Track
from app.db.models.user import User


@pytest.fixture
async def user_a(async_client: AsyncClient) -> dict:
    """Creates user A and returns authentication headers."""
    email = f"user_a_{uuid.uuid4().hex[:8]}@example.com"
    password = "SecurePassword123!"
    res = await async_client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": password, "name": "User Alpha"},
    )
    assert res.status_code == 201
    data = res.json()["data"]
    return {
        "headers": {"Authorization": f"Bearer {data['access_token']}"},
        "user_id": uuid.UUID(data["user"]["id"]),
    }


@pytest.fixture
async def user_b(async_client: AsyncClient) -> dict:
    """Creates user B for account isolation checks."""
    email = f"user_b_{uuid.uuid4().hex[:8]}@example.com"
    password = "SecurePassword123!"
    res = await async_client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": password, "name": "User Beta"},
    )
    assert res.status_code == 201
    data = res.json()["data"]
    return {
        "headers": {"Authorization": f"Bearer {data['access_token']}"},
        "user_id": uuid.UUID(data["user"]["id"]),
    }


@pytest.fixture
async def multi_tier_track(db_session: AsyncSession, user_a: dict) -> Track:
    """Creates a track with HIGH (192k), MEDIUM (128k), and LOW (64k) renditions."""
    track_id = uuid.uuid4()
    track = Track(
        id=track_id,
        owner_id=user_a["user_id"],
        title="Multi-Bitrate Masterpiece",
        artist_name="Audiophile Pro",
        genre="Ambient",
        duration_seconds=200,
        status="READY",
    )
    r_high = AudioRendition(
        id=uuid.uuid4(),
        track_id=track_id,
        storage_key=f"audio/{track_id}/192k.m4a",
        storage_provider="s3",
        format="m4a",
        codec="aac",
        bitrate_kbps=192,
        file_size_bytes=4800000,
        duration_seconds=200,
    )
    r_med = AudioRendition(
        id=uuid.uuid4(),
        track_id=track_id,
        storage_key=f"audio/{track_id}/128k.m4a",
        storage_provider="s3",
        format="m4a",
        codec="aac",
        bitrate_kbps=128,
        file_size_bytes=3200000,
        duration_seconds=200,
    )
    r_low = AudioRendition(
        id=uuid.uuid4(),
        track_id=track_id,
        storage_key=f"audio/{track_id}/64k.m4a",
        storage_provider="s3",
        format="m4a",
        codec="aac",
        bitrate_kbps=64,
        file_size_bytes=1600000,
        duration_seconds=200,
    )
    db_session.add(track)
    db_session.add(r_high)
    db_session.add(r_med)
    db_session.add(r_low)
    await db_session.commit()
    await db_session.refresh(track)
    return track


@pytest.fixture
async def low_medium_track(db_session: AsyncSession, user_a: dict) -> Track:
    """Creates a track that only has MEDIUM (128k) and LOW (64k) renditions (HIGH missing)."""
    track_id = uuid.uuid4()
    track = Track(
        id=track_id,
        owner_id=user_a["user_id"],
        title="Constrained Ladder Track",
        duration_seconds=150,
        status="READY",
    )
    r_med = AudioRendition(
        id=uuid.uuid4(),
        track_id=track_id,
        storage_key=f"audio/{track_id}/128k.m4a",
        storage_provider="s3",
        format="m4a",
        codec="aac",
        bitrate_kbps=128,
        file_size_bytes=2400000,
        duration_seconds=150,
    )
    r_low = AudioRendition(
        id=uuid.uuid4(),
        track_id=track_id,
        storage_key=f"audio/{track_id}/64k.m4a",
        storage_provider="s3",
        format="m4a",
        codec="aac",
        bitrate_kbps=64,
        file_size_bytes=1200000,
        duration_seconds=150,
    )
    db_session.add(track)
    db_session.add(r_med)
    db_session.add(r_low)
    await db_session.commit()
    await db_session.refresh(track)
    return track


# ==============================================================================
# Playback Settings API Tests
# ==============================================================================

class TestPlaybackSettingsAPI:
    """Verifies settings retrieval, updates, and validation."""

    async def test_get_settings_default(self, async_client: AsyncClient, user_a: dict):
        """Newly created user should receive standard default playback preferences."""
        res = await async_client.get(
            "/api/v1/settings/playback",
            headers=user_a["headers"],
        )
        assert res.status_code == 200
        data = res.json()["data"]
        assert data["streaming_quality"] == "AUTO"
        assert data["mobile_data_quality"] == "LOW"
        assert data["wifi_quality"] == "HIGH"
        assert data["download_quality"] == "HIGH"
        assert data["data_saver_enabled"] is False

    async def test_get_settings_unauthenticated(self, async_client: AsyncClient):
        """Unauthenticated requests must be rejected with 401."""
        res = await async_client.get("/api/v1/settings/playback")
        assert res.status_code == 401

    async def test_update_settings_success(self, async_client: AsyncClient, user_a: dict):
        """Updating playback preferences succeeds and persists."""
        payload = {
            "streaming_quality": "HIGH",
            "mobile_data_quality": "MEDIUM",
            "wifi_quality": "HIGH",
            "download_quality": "MEDIUM",
            "data_saver_enabled": True,
        }
        res = await async_client.put(
            "/api/v1/settings/playback",
            headers=user_a["headers"],
            json=payload,
        )
        assert res.status_code == 200
        data = res.json()["data"]
        assert data["streaming_quality"] == "HIGH"
        assert data["mobile_data_quality"] == "MEDIUM"
        assert data["wifi_quality"] == "HIGH"
        assert data["download_quality"] == "MEDIUM"
        assert data["data_saver_enabled"] is True

        # Re-fetch to confirm persistence
        get_res = await async_client.get(
            "/api/v1/settings/playback",
            headers=user_a["headers"],
        )
        assert get_res.status_code == 200
        persisted = get_res.json()["data"]
        assert persisted["streaming_quality"] == "HIGH"
        assert persisted["data_saver_enabled"] is True

    async def test_update_settings_validation_failure(
        self, async_client: AsyncClient, user_a: dict
    ):
        """Reject unknown quality values with HTTP 422."""
        res = await async_client.put(
            "/api/v1/settings/playback",
            headers=user_a["headers"],
            json={"streaming_quality": "ULTRA_SUPER_HD"},
        )
        assert res.status_code == 422

        res_dl = await async_client.put(
            "/api/v1/settings/playback",
            headers=user_a["headers"],
            json={"download_quality": "AUTO"},  # Download quality requires explicit tier
        )
        assert res_dl.status_code == 422

    async def test_settings_user_isolation(
        self, async_client: AsyncClient, user_a: dict, user_b: dict
    ):
        """User A settings must not leak or mutate User B settings."""
        # User A enables data saver
        await async_client.put(
            "/api/v1/settings/playback",
            headers=user_a["headers"],
            json={"data_saver_enabled": True, "streaming_quality": "LOW"},
        )

        # User B settings must remain default
        res_b = await async_client.get(
            "/api/v1/settings/playback",
            headers=user_b["headers"],
        )
        assert res_b.status_code == 200
        data_b = res_b.json()["data"]
        assert data_b["data_saver_enabled"] is False
        assert data_b["streaming_quality"] == "AUTO"


# ==============================================================================
# Playback Quality Selection Tests
# ==============================================================================

class TestPlaybackQualitySelection:
    """Verifies track playback rendition selection according to requested quality tier."""

    async def test_playback_default_auto(
        self, async_client: AsyncClient, user_a: dict, multi_tier_track: Track
    ):
        """AUTO quality returns the highest available rendition (192k)."""
        res = await async_client.get(
            f"/api/v1/audio/tracks/{multi_tier_track.id}/playback",
            headers=user_a["headers"],
        )
        assert res.status_code == 200
        data = res.json()["data"]
        assert data["audio"]["bitrate_kbps"] == 192
        assert data["audio"]["quality"] == "HIGH"
        assert len(data["available_renditions"]) == 3

    async def test_playback_explicit_high(
        self, async_client: AsyncClient, user_a: dict, multi_tier_track: Track
    ):
        """Explicit HIGH quality selects 192k rendition."""
        res = await async_client.get(
            f"/api/v1/audio/tracks/{multi_tier_track.id}/playback?quality=HIGH",
            headers=user_a["headers"],
        )
        assert res.status_code == 200
        data = res.json()["data"]
        assert data["audio"]["bitrate_kbps"] == 192
        assert data["audio"]["quality"] == "HIGH"

    async def test_playback_explicit_medium(
        self, async_client: AsyncClient, user_a: dict, multi_tier_track: Track
    ):
        """Explicit MEDIUM quality selects 128k rendition."""
        res = await async_client.get(
            f"/api/v1/audio/tracks/{multi_tier_track.id}/playback?quality=MEDIUM",
            headers=user_a["headers"],
        )
        assert res.status_code == 200
        data = res.json()["data"]
        assert data["audio"]["bitrate_kbps"] == 128
        assert data["audio"]["quality"] == "MEDIUM"

    async def test_playback_explicit_low(
        self, async_client: AsyncClient, user_a: dict, multi_tier_track: Track
    ):
        """Explicit LOW quality selects 64k rendition."""
        res = await async_client.get(
            f"/api/v1/audio/tracks/{multi_tier_track.id}/playback?quality=LOW",
            headers=user_a["headers"],
        )
        assert res.status_code == 200
        data = res.json()["data"]
        assert data["audio"]["bitrate_kbps"] == 64
        assert data["audio"]["quality"] == "LOW"

    async def test_playback_fallback_when_tier_missing(
        self, async_client: AsyncClient, user_a: dict, low_medium_track: Track
    ):
        """When HIGH is requested on a track with only MEDIUM and LOW, falls back to 128k."""
        res = await async_client.get(
            f"/api/v1/audio/tracks/{low_medium_track.id}/playback?quality=HIGH",
            headers=user_a["headers"],
        )
        assert res.status_code == 200
        data = res.json()["data"]
        # Nearest rendition to 192k in [128k, 64k] is 128k
        assert data["audio"]["bitrate_kbps"] == 128
        assert data["audio"]["quality"] == "MEDIUM"


# ==============================================================================
# Download Quality Selection Tests
# ==============================================================================

class TestDownloadQualitySelection:
    """Verifies track download resource selection based on requested quality."""

    async def test_download_high_quality(
        self, async_client: AsyncClient, user_a: dict, multi_tier_track: Track
    ):
        """Downloading at HIGH quality generates URL for 192k rendition."""
        res = await async_client.get(
            f"/api/v1/audio/tracks/{multi_tier_track.id}/download?quality=HIGH",
            headers=user_a["headers"],
        )
        assert res.status_code == 200
        data = res.json()["data"]
        assert data["bitrate_kbps"] == 192
        assert data["quality"] == "HIGH"
        assert "download_url" in data

    async def test_download_low_quality(
        self, async_client: AsyncClient, user_a: dict, multi_tier_track: Track
    ):
        """Downloading at LOW quality generates URL for 64k rendition (saving disk space)."""
        res = await async_client.get(
            f"/api/v1/audio/tracks/{multi_tier_track.id}/download?quality=LOW",
            headers=user_a["headers"],
        )
        assert res.status_code == 200
        data = res.json()["data"]
        assert data["bitrate_kbps"] == 64
        assert data["quality"] == "LOW"
        assert data["file_size_bytes"] == 1600000

    async def test_download_unauthorized_user_forbidden(
        self, async_client: AsyncClient, user_b: dict, multi_tier_track: Track
    ):
        """User B cannot download User A's private track."""
        res = await async_client.get(
            f"/api/v1/audio/tracks/{multi_tier_track.id}/download?quality=HIGH",
            headers=user_b["headers"],
        )
        assert res.status_code == 403
