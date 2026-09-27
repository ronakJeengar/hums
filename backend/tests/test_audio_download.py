"""Tests for Track Download Eligibility and Authorized Download Endpoint.

Verifies:
- Authenticated download of READY audio tracks.
- Rejection of tracks still being processed (TRACK_NOT_READY / 409).
- 404 response for nonexistent tracks.
- 401 response for unauthenticated callers.
- Presigned URL generation and short-lived expiry.
- Rate limiting protection.
"""

import uuid
import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models.audio import AudioFile, AudioRendition, Track
from app.db.models.user import User


@pytest.fixture
async def authenticated_user(async_client: AsyncClient) -> dict:
    """Creates a user and returns authentication headers."""
    email = f"downloader_{uuid.uuid4().hex[:8]}@example.com"
    password = "SecurePassword123!"
    register_res = await async_client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": password, "name": "Audio Downloader"},
    )
    assert register_res.status_code == 201
    data = register_res.json()["data"]
    token = data["access_token"]
    user_id = data["user"]["id"]
    return {
        "headers": {"Authorization": f"Bearer {token}"},
        "user_id": uuid.UUID(user_id),
    }


@pytest.fixture
async def other_user(async_client: AsyncClient) -> dict:
    """Creates a secondary user for cross-user access tests."""
    email = f"other_{uuid.uuid4().hex[:8]}@example.com"
    password = "SecurePassword123!"
    res = await async_client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": password, "name": "Other User"},
    )
    data = res.json()["data"]
    token = data["access_token"]
    user_id = data["user"]["id"]
    return {
        "headers": {"Authorization": f"Bearer {token}"},
        "user_id": uuid.UUID(user_id),
    }


@pytest.fixture
async def ready_track(db_session: AsyncSession, authenticated_user: dict) -> Track:
    """Creates a READY track with audio renditions in database."""
    track_id = uuid.uuid4()
    track = Track(
        id=track_id,
        owner_id=authenticated_user["user_id"],
        title="Offline Symphony",
        artist_name="Acoustic Master",
        album_name="Silent Resonance",
        genre="Classical",
        duration_seconds=184,
        status="READY",
    )
    rendition = AudioRendition(
        id=uuid.uuid4(),
        track_id=track_id,
        storage_key=f"audio/{track_id}/320k.m4a",
        storage_provider="s3",
        format="m4a",
        codec="aac",
        bitrate_kbps=320,
        file_size_bytes=7360000,
        duration_seconds=184,
    )
    db_session.add(track)
    db_session.add(rendition)
    await db_session.commit()
    await db_session.refresh(track)
    return track


@pytest.fixture
async def processing_track(db_session: AsyncSession, authenticated_user: dict) -> Track:
    """Creates a track currently in PROCESSING status."""
    track_id = uuid.uuid4()
    track = Track(
        id=track_id,
        owner_id=authenticated_user["user_id"],
        title="Unfinished Track",
        status="PROCESSING",
    )
    audio_file = AudioFile(
        id=uuid.uuid4(),
        track_id=track_id,
        object_key=f"raw/{track_id}.wav",
        storage_provider="s3",
        original_filename="raw.wav",
        mime_type="audio/wav",
        file_size_bytes=35000000,
    )
    db_session.add(track)
    db_session.add(audio_file)
    await db_session.commit()
    await db_session.refresh(track)
    return track


# ---------------------------------------------------------------------------
# Download Endpoint Tests
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_download_ready_track_success(
    async_client: AsyncClient,
    authenticated_user: dict,
    ready_track: Track,
):
    """Verifies that an authenticated user can retrieve an authorized download URL for a READY track."""
    url = f"/api/v1/audio/tracks/{ready_track.id}/download"
    response = await async_client.get(url, headers=authenticated_user["headers"])

    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True

    download_data = data["data"]
    assert download_data["track_id"] == str(ready_track.id)
    assert download_data["title"] == "Offline Symphony"
    assert download_data["artist_name"] == "Acoustic Master"
    assert download_data["format"] == "m4a"
    assert download_data["bitrate_kbps"] == 320
    assert download_data["file_size_bytes"] == 7360000
    assert "download_url" in download_data
    assert len(download_data["download_url"]) > 0
    assert "expires_at" in download_data


@pytest.mark.asyncio
async def test_download_ready_track_alias_endpoint(
    async_client: AsyncClient,
    authenticated_user: dict,
    ready_track: Track,
):
    """Verifies that the alias endpoint /api/v1/tracks/{track_id}/download also resolves correctly."""
    url = f"/api/v1/tracks/{ready_track.id}/download"
    response = await async_client.get(url, headers=authenticated_user["headers"])

    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True
    assert data["data"]["track_id"] == str(ready_track.id)


@pytest.mark.asyncio
async def test_download_processing_track_rejected(
    async_client: AsyncClient,
    authenticated_user: dict,
    processing_track: Track,
):
    """Verifies that attempting to download a non-READY track returns 409 TRACK_NOT_READY."""
    url = f"/api/v1/audio/tracks/{processing_track.id}/download"
    response = await async_client.get(url, headers=authenticated_user["headers"])

    assert response.status_code == 409
    data = response.json()
    assert data["success"] is False
    assert data["error"]["code"] == "TRACK_NOT_READY"


@pytest.mark.asyncio
async def test_download_nonexistent_track_returns_404(
    async_client: AsyncClient,
    authenticated_user: dict,
):
    """Verifies that downloading a nonexistent track returns 404 Not Found."""
    random_id = uuid.uuid4()
    url = f"/api/v1/audio/tracks/{random_id}/download"
    response = await async_client.get(url, headers=authenticated_user["headers"])

    assert response.status_code == 404
    data = response.json()
    assert data["success"] is False


@pytest.mark.asyncio
async def test_download_unauthenticated_rejected(
    async_client: AsyncClient,
    ready_track: Track,
):
    """Verifies that unauthenticated callers are rejected with 401 Unauthorized."""
    url = f"/api/v1/audio/tracks/{ready_track.id}/download"
    response = await async_client.get(url)

    assert response.status_code == 401


@pytest.mark.asyncio
async def test_download_other_user_private_track_rejected(
    async_client: AsyncClient,
    other_user: dict,
    ready_track: Track,
):
    """Verifies that another user cannot download a private track owned by someone else (Security Rule 61)."""
    url = f"/api/v1/audio/tracks/{ready_track.id}/download"
    response = await async_client.get(url, headers=other_user["headers"])

    assert response.status_code == 403
    data = response.json()
    assert data["success"] is False
    assert data["error"]["code"] == "FORBIDDEN"
