import asyncio
import uuid
import pytest
from httpx import AsyncClient
from unittest.mock import AsyncMock, patch

from app.ai.gemini_lyrics_client import GeminiLyricsClient
from app.db.database import AsyncSessionLocal
from app.db.models.audio import Track
from app.db.models.lyrics import LyricLine, Lyrics, LyricsSource, LyricsStatus
from app.repositories.audio_repository import TrackRepository
from app.repositories.lyrics_repository import LyricsRepository
from app.services.lyrics_service import LyricsService


@pytest.fixture
async def lyrics_user1(async_client: AsyncClient):
    """User 1 fixture (track owner)."""
    email = f"lyrics_u1_{uuid.uuid4().hex[:8]}@example.com"
    password = "SecurePassword123!"
    res = await async_client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": password, "name": "Aarav Sharma"},
    )
    assert res.status_code == 201
    data = res.json()["data"]
    token = data["access_token"]
    return {
        "id": uuid.UUID(data["user"]["id"]),
        "access_token": token,
        "headers": {"Authorization": f"Bearer {token}"},
        "user": data["user"],
    }


@pytest.fixture
async def lyrics_user2(async_client: AsyncClient):
    """User 2 fixture (another user)."""
    email = f"lyrics_u2_{uuid.uuid4().hex[:8]}@example.com"
    password = "SecurePassword123!"
    res = await async_client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": password, "name": "Diya Sen"},
    )
    assert res.status_code == 201
    data = res.json()["data"]
    token = data["access_token"]
    return {
        "id": uuid.UUID(data["user"]["id"]),
        "access_token": token,
        "headers": {"Authorization": f"Bearer {token}"},
        "user": data["user"],
    }


@pytest.fixture
async def ready_track(lyrics_user1):
    """Creates a sample track in READY status."""
    async with AsyncSessionLocal() as session:
        track = Track(
            owner_id=lyrics_user1["id"],
            title="Sunrise Acoustic",
            artist_name="Luna Wave",
            album_name="Golden Hour",
            genre="Acoustic",
            duration_seconds=210,
            status="READY",
        )
        session.add(track)
        await session.commit()
        await session.refresh(track)
        return track


@pytest.fixture
async def unready_track(lyrics_user1):
    """Creates a sample track in UPLOADED (not READY) status."""
    async with AsyncSessionLocal() as session:
        track = Track(
            owner_id=lyrics_user1["id"],
            title="Processing Track",
            artist_name="Luna Wave",
            status="UPLOADED",
        )
        session.add(track)
        await session.commit()
        await session.refresh(track)
        return track


class TestLyricsEndpoints:
    """Verifies REST endpoints for retrieving, uploading, and generating lyrics."""

    async def test_get_lyrics_non_existent_track(self, async_client: AsyncClient):
        fake_id = uuid.uuid4()
        res = await async_client.get(f"/api/v1/tracks/{fake_id}/lyrics")
        assert res.status_code == 404

    async def test_get_lyrics_unready_track(self, async_client: AsyncClient, unready_track: Track):
        res = await async_client.get(f"/api/v1/tracks/{unready_track.id}/lyrics")
        assert res.status_code == 409
        body = res.json()
        assert body["error"]["code"] == "TRACK_NOT_READY"

    async def test_get_lyrics_ready_track_without_lyrics_returns_unavailable(
        self, async_client: AsyncClient, ready_track: Track
    ):
        res = await async_client.get(f"/api/v1/tracks/{ready_track.id}/lyrics")
        assert res.status_code == 200
        data = res.json()["data"]
        assert data["track_id"] == str(ready_track.id)
        assert data["status"] == "UNAVAILABLE"
        assert data["is_synchronized"] is False
        assert data["lines"] == []

    async def test_upload_plain_lyrics_success(
        self, async_client: AsyncClient, lyrics_user1: dict, ready_track: Track
    ):
        payload = {
            "text": "Verse 1:\nThe sun is rising high\nClear blue sky",
            "language": "en",
            "is_synchronized": False,
        }
        res = await async_client.post(
            f"/api/v1/tracks/{ready_track.id}/lyrics",
            json=payload,
            headers=lyrics_user1["headers"],
        )
        assert res.status_code == 200
        data = res.json()["data"]
        assert data["track_id"] == str(ready_track.id)
        assert data["status"] == "COMPLETED"
        assert data["is_synchronized"] is False
        assert "The sun is rising high" in data["text"]
        assert data["lines"] == []

        # Verify retrieval endpoint returns the newly saved lyrics
        get_res = await async_client.get(f"/api/v1/tracks/{ready_track.id}/lyrics")
        assert get_res.status_code == 200
        assert get_res.json()["data"]["text"] == data["text"]

    async def test_upload_synchronized_lyrics_success(
        self, async_client: AsyncClient, lyrics_user1: dict, ready_track: Track
    ):
        payload = {
            "language": "en",
            "is_synchronized": True,
            "lines": [
                {"sequence": 0, "start_ms": 10500, "end_ms": 14200, "text": "First acoustic chord"},
                {"sequence": 1, "start_ms": 14500, "end_ms": 18000, "text": "Walking down the shoreline"},
                {"sequence": 2, "start_ms": 18500, "end_ms": 22000, "text": "Golden morning light"},
            ],
        }
        res = await async_client.post(
            f"/api/v1/tracks/{ready_track.id}/lyrics",
            json=payload,
            headers=lyrics_user1["headers"],
        )
        assert res.status_code == 200
        data = res.json()["data"]
        assert data["is_synchronized"] is True
        assert len(data["lines"]) == 3
        assert data["lines"][0]["sequence"] == 0
        assert data["lines"][0]["start_ms"] == 10500
        assert data["lines"][0]["text"] == "First acoustic chord"
        assert data["lines"][1]["start_ms"] == 14500

    async def test_upload_lyrics_forbidden_by_non_owner(
        self, async_client: AsyncClient, lyrics_user2: dict, ready_track: Track
    ):
        payload = {"text": "Unauthorized lyrics attempt"}
        res = await async_client.post(
            f"/api/v1/tracks/{ready_track.id}/lyrics",
            json=payload,
            headers=lyrics_user2["headers"],
        )
        assert res.status_code == 403

    async def test_upload_lyrics_rejects_negative_start_ms(
        self, async_client: AsyncClient, lyrics_user1: dict, ready_track: Track
    ):
        payload = {
            "is_synchronized": True,
            "lines": [
                {"sequence": 0, "start_ms": -500, "text": "Negative start"},
            ],
        }
        res = await async_client.post(
            f"/api/v1/tracks/{ready_track.id}/lyrics",
            json=payload,
            headers=lyrics_user1["headers"],
        )
        assert res.status_code == 422  # Pydantic ge=0 validation

    async def test_upload_lyrics_rejects_out_of_order_timestamps(
        self, async_client: AsyncClient, lyrics_user1: dict, ready_track: Track
    ):
        payload = {
            "is_synchronized": True,
            "lines": [
                {"sequence": 0, "start_ms": 15000, "end_ms": 18000, "text": "Line 1"},
                {"sequence": 1, "start_ms": 12000, "end_ms": 14000, "text": "Line 2 (earlier than line 1)"},
            ],
        }
        res = await async_client.post(
            f"/api/v1/tracks/{ready_track.id}/lyrics",
            json=payload,
            headers=lyrics_user1["headers"],
        )
        assert res.status_code == 400
        assert res.json()["error"]["code"] == "INVALID_LYRIC_TIMESTAMPS"

    async def test_upload_lyrics_rejects_end_ms_less_than_start_ms(
        self, async_client: AsyncClient, lyrics_user1: dict, ready_track: Track
    ):
        payload = {
            "is_synchronized": True,
            "lines": [
                {"sequence": 0, "start_ms": 15000, "end_ms": 10000, "text": "End before start"},
            ],
        }
        res = await async_client.post(
            f"/api/v1/tracks/{ready_track.id}/lyrics",
            json=payload,
            headers=lyrics_user1["headers"],
        )
        assert res.status_code == 400
        assert res.json()["error"]["code"] == "INVALID_LYRIC_TIMESTAMPS"

    async def test_trigger_lyrics_generation_enqueues_task(
        self, async_client: AsyncClient, lyrics_user1: dict, ready_track: Track
    ):
        with patch("app.workers.lyrics_tasks.generate_track_lyrics.delay") as mock_delay:
            res = await async_client.post(
                f"/api/v1/tracks/{ready_track.id}/lyrics/generate",
                headers=lyrics_user1["headers"],
            )
            assert res.status_code == 202
            data = res.json()["data"]
            assert data["track_id"] == str(ready_track.id)
            assert data["status"] == "PROCESSING"
            mock_delay.assert_called_once_with(str(ready_track.id))


class TestLyricsServiceAndAI:
    """Verifies unit behavior of LyricsService and Gemini integration."""

    async def test_gemini_client_disabled_without_api_key(self):
        client = GeminiLyricsClient(api_key="")
        assert client.is_available is False
        result = await client.generate_lyrics(title="Sample")
        assert result is None

    async def test_service_generates_synchronized_lyrics(self, ready_track: Track):
        mock_client = AsyncMock(spec=GeminiLyricsClient)
        mock_client.model = "gemini-2.5-flash"
        mock_client.version = "v1"
        mock_client.generate_lyrics.return_value = {
            "language": "en",
            "is_synchronized": True,
            "lines": [
                {"sequence": 0, "start_ms": 5000, "end_ms": 9000, "text": "Sun coming up"},
                {"sequence": 1, "start_ms": 9500, "end_ms": 14000, "text": "Shadows fade away"},
            ],
            "plain_text": "Sun coming up\nShadows fade away",
        }

        async with AsyncSessionLocal() as session:
            lyrics_repo = LyricsRepository(session)
            track_repo = TrackRepository(session)
            service = LyricsService(
                lyrics_repo=lyrics_repo,
                track_repo=track_repo,
                gemini_client=mock_client,
            )

            response = await service.generate_lyrics(ready_track.id)
            assert response.status == LyricsStatus.COMPLETED
            assert response.is_synchronized is True
            assert len(response.lines) == 2
            assert response.lines[0].text == "Sun coming up"
            assert response.lines[1].start_ms == 9500

    async def test_service_falls_back_when_ai_fails(self, ready_track: Track):
        mock_client = AsyncMock(spec=GeminiLyricsClient)
        mock_client.model = "gemini-2.5-flash"
        mock_client.version = "v1"
        mock_client.generate_lyrics.return_value = None

        async with AsyncSessionLocal() as session:
            lyrics_repo = LyricsRepository(session)
            track_repo = TrackRepository(session)
            service = LyricsService(
                lyrics_repo=lyrics_repo,
                track_repo=track_repo,
                gemini_client=mock_client,
            )

            response = await service.generate_lyrics(ready_track.id)
            assert response.status == LyricsStatus.UNAVAILABLE
            assert response.is_synchronized is False
            assert len(response.lines) == 0
