import uuid
from datetime import datetime, timedelta, timezone
import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession
from app.db.models.playback import PlaybackEvent, TrackPlaybackProgress
from app.services.playback_service import PlaybackService


@pytest.fixture
async def user1_auth(async_client: AsyncClient):
    """Registers and authenticates User 1."""
    email = f"history_user1_{uuid.uuid4().hex[:8]}@example.com"
    password = "SecurePassword123!"
    res = await async_client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": password, "name": "History User One"},
    )
    assert res.status_code == 201
    data = res.json()["data"]
    token = data["access_token"]
    return {
        "access_token": token,
        "headers": {"Authorization": f"Bearer {token}"},
        "user": data["user"],
    }


@pytest.fixture
async def user2_auth(async_client: AsyncClient):
    """Registers and authenticates User 2 for isolation tests."""
    email = f"history_user2_{uuid.uuid4().hex[:8]}@example.com"
    password = "SecurePassword123!"
    res = await async_client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": password, "name": "History User Two"},
    )
    assert res.status_code == 201
    data = res.json()["data"]
    token = data["access_token"]
    return {
        "access_token": token,
        "headers": {"Authorization": f"Bearer {token}"},
        "user": data["user"],
    }


@pytest.fixture
async def track_one_id(async_client: AsyncClient, user1_auth):
    """Uploads a primary test track."""
    fake_mp3 = b"ID3\x03\x00\x00\x00\x00\x00\x21" + b"\xFF\xFB\x90\x44" + (b"\x00" * 200)
    files = {"file": ("test_track1.mp3", fake_mp3, "audio/mpeg")}
    data = {
        "title": "Acoustic Sun",
        "artist_name": "Solar Strings",
        "album_name": "Helios",
        "genre": "Acoustic",
    }
    res = await async_client.post(
        "/api/v1/audio/upload",
        files=files,
        data=data,
        headers=user1_auth["headers"],
    )
    assert res.status_code == 201
    return res.json()["data"]["id"]


@pytest.fixture
async def track_two_id(async_client: AsyncClient, user1_auth):
    """Uploads a secondary test track."""
    fake_mp3 = b"ID3\x03\x00\x00\x00\x00\x00\x21" + b"\xFF\xFB\x90\x44" + (b"\x00" * 300)
    files = {"file": ("test_track2.mp3", fake_mp3, "audio/mpeg")}
    data = {
        "title": "Midnight Reverie",
        "artist_name": "Lunar Wave",
        "album_name": "Night Sky",
        "genre": "Ambient",
    }
    res = await async_client.post(
        "/api/v1/audio/upload",
        files=files,
        data=data,
        headers=user1_auth["headers"],
    )
    assert res.status_code == 201
    return res.json()["data"]["id"]


class TestPlaybackEvents:
    @pytest.mark.asyncio
    async def test_record_single_event_success(
        self, async_client: AsyncClient, user1_auth, track_one_id
    ):
        event_id = str(uuid.uuid4())
        played_at = datetime.now(timezone.utc).isoformat()

        res = await async_client.post(
            "/api/v1/playback/events",
            json={
                "event_id": event_id,
                "track_id": track_one_id,
                "event_type": "PLAY_STARTED",
                "position_ms": 0,
                "duration_ms": 180000,
                "played_at": played_at,
                "source": "player",
                "device_id": "test_device_1",
            },
            headers=user1_auth["headers"],
        )
        assert res.status_code == 200
        data = res.json()["data"]
        assert data["accepted_count"] == 1
        assert data["duplicate_count"] == 0

    @pytest.mark.asyncio
    async def test_event_idempotency_prevents_duplicates(
        self, async_client: AsyncClient, user1_auth, track_one_id
    ):
        event_id = str(uuid.uuid4())
        played_at = datetime.now(timezone.utc).isoformat()

        payload = {
            "event_id": event_id,
            "track_id": track_one_id,
            "event_type": "PROGRESS_CHECKPOINT",
            "position_ms": 30000,
            "duration_ms": 180000,
            "played_at": played_at,
            "source": "player",
        }

        # First request: accepted
        res1 = await async_client.post(
            "/api/v1/playback/events",
            json=payload,
            headers=user1_auth["headers"],
        )
        assert res1.status_code == 200
        assert res1.json()["data"]["accepted_count"] == 1
        assert res1.json()["data"]["duplicate_count"] == 0

        # Second request with same event_id: duplicate skipped idempotently
        res2 = await async_client.post(
            "/api/v1/playback/events",
            json=payload,
            headers=user1_auth["headers"],
        )
        assert res2.status_code == 200
        assert res2.json()["data"]["accepted_count"] == 0
        assert res2.json()["data"]["duplicate_count"] == 1

    @pytest.mark.asyncio
    async def test_batch_event_ingestion_from_offline_sync(
        self, async_client: AsyncClient, user1_auth, track_one_id, track_two_id
    ):
        now = datetime.now(timezone.utc)
        ev1_id = str(uuid.uuid4())
        ev2_id = str(uuid.uuid4())
        ev3_id = str(uuid.uuid4())

        batch_payload = {
            "events": [
                {
                    "event_id": ev1_id,
                    "track_id": track_one_id,
                    "event_type": "PLAY_STARTED",
                    "position_ms": 0,
                    "duration_ms": 180000,
                    "played_at": (now - timedelta(minutes=10)).isoformat(),
                    "source": "offline_sync",
                },
                {
                    "event_id": ev2_id,
                    "track_id": track_one_id,
                    "event_type": "PROGRESS_CHECKPOINT",
                    "position_ms": 90000,
                    "duration_ms": 180000,
                    "played_at": (now - timedelta(minutes=8)).isoformat(),
                    "source": "offline_sync",
                },
                {
                    "event_id": ev3_id,
                    "track_id": track_two_id,
                    "event_type": "COMPLETED",
                    "position_ms": 200000,
                    "duration_ms": 200000,
                    "played_at": (now - timedelta(minutes=2)).isoformat(),
                    "source": "offline_sync",
                },
            ]
        }

        res = await async_client.post(
            "/api/v1/playback/events",
            json=batch_payload,
            headers=user1_auth["headers"],
        )
        assert res.status_code == 200
        data = res.json()["data"]
        assert data["accepted_count"] == 3
        assert data["duplicate_count"] == 0

        # Submitting again should report all 3 duplicates
        res_dup = await async_client.post(
            "/api/v1/playback/events",
            json=batch_payload,
            headers=user1_auth["headers"],
        )
        assert res_dup.status_code == 200
        assert res_dup.json()["data"]["accepted_count"] == 0
        assert res_dup.json()["data"]["duplicate_count"] == 3

    @pytest.mark.asyncio
    async def test_future_timestamp_rejected(
        self, async_client: AsyncClient, user1_auth, track_one_id
    ):
        event_id = str(uuid.uuid4())
        future_time = (datetime.now(timezone.utc) + timedelta(days=5)).isoformat()

        res = await async_client.post(
            "/api/v1/playback/events",
            json={
                "event_id": event_id,
                "track_id": track_one_id,
                "event_type": "PLAY_STARTED",
                "position_ms": 0,
                "duration_ms": 100000,
                "played_at": future_time,
            },
            headers=user1_auth["headers"],
        )
        assert res.status_code == 400
        assert "future" in res.json()["error"]["message"].lower()


class TestPlaybackProgress:
    @pytest.mark.asyncio
    async def test_update_and_get_progress(
        self, async_client: AsyncClient, user1_auth, track_one_id
    ):
        # Initial lookup for unplayed track
        res_init = await async_client.get(
            f"/api/v1/playback/progress/{track_one_id}",
            headers=user1_auth["headers"],
        )
        assert res_init.status_code == 200
        assert res_init.json()["data"]["position_ms"] == 0
        assert res_init.json()["data"]["completed"] is False

        # Update progress to 45 seconds (45,000 ms) of 180 seconds
        res_up = await async_client.put(
            f"/api/v1/playback/progress/{track_one_id}",
            json={
                "position_ms": 45000,
                "duration_ms": 180000,
            },
            headers=user1_auth["headers"],
        )
        assert res_up.status_code == 200
        data_up = res_up.json()["data"]
        assert data_up["position_ms"] == 45000
        assert data_up["duration_ms"] == 180000
        assert data_up["completed"] is False
        assert data_up["progress_percent"] == 0.25

        # Verify get endpoint returns updated progress
        res_get = await async_client.get(
            f"/api/v1/playback/progress/{track_one_id}",
            headers=user1_auth["headers"],
        )
        assert res_get.status_code == 200
        assert res_get.json()["data"]["position_ms"] == 45000

    @pytest.mark.asyncio
    async def test_progress_completion_threshold(
        self, async_client: AsyncClient, user1_auth, track_one_id
    ):
        # 96% progress (173,000 / 180,000) should mark completed = True
        res = await async_client.put(
            f"/api/v1/playback/progress/{track_one_id}",
            json={
                "position_ms": 173000,
                "duration_ms": 180000,
            },
            headers=user1_auth["headers"],
        )
        assert res.status_code == 200
        assert res.json()["data"]["completed"] is True

        # Replaying track from 0 should reset completed to False
        res_replay = await async_client.put(
            f"/api/v1/playback/progress/{track_one_id}",
            json={
                "position_ms": 0,
                "duration_ms": 180000,
            },
            headers=user1_auth["headers"],
        )
        assert res_replay.status_code == 200
        assert res_replay.json()["data"]["completed"] is False
        assert res_replay.json()["data"]["position_ms"] == 0

    @pytest.mark.asyncio
    async def test_batch_progress_lookup(
        self, async_client: AsyncClient, user1_auth, track_one_id, track_two_id
    ):
        # Set progress for track 1
        await async_client.put(
            f"/api/v1/playback/progress/{track_one_id}",
            json={"position_ms": 50000, "duration_ms": 100000},
            headers=user1_auth["headers"],
        )

        res = await async_client.get(
            f"/api/v1/playback/progress?track_ids={track_one_id},{track_two_id}",
            headers=user1_auth["headers"],
        )
        assert res.status_code == 200
        items = res.json()["data"]["items"]
        assert len(items) == 2

        item_map = {item["track_id"]: item for item in items}
        assert item_map[track_one_id]["position_ms"] == 50000
        assert item_map[track_two_id]["position_ms"] == 0

    @pytest.mark.asyncio
    async def test_batch_progress_invalid_uuid_rejected(
        self, async_client: AsyncClient, user1_auth
    ):
        res = await async_client.get(
            "/api/v1/playback/progress?track_ids=not-a-valid-uuid",
            headers=user1_auth["headers"],
        )
        assert res.status_code == 400


class TestListeningHistory:
    @pytest.mark.asyncio
    async def test_listening_history_feed_and_pagination(
        self, async_client: AsyncClient, user1_auth, track_one_id, track_two_id
    ):
        now = datetime.now(timezone.utc)

        # User plays track 1 first
        await async_client.post(
            "/api/v1/playback/events",
            json={
                "event_id": str(uuid.uuid4()),
                "track_id": track_one_id,
                "event_type": "PLAY_STARTED",
                "position_ms": 20000,
                "duration_ms": 180000,
                "played_at": (now - timedelta(minutes=20)).isoformat(),
            },
            headers=user1_auth["headers"],
        )

        # User plays track 2 later
        await async_client.post(
            "/api/v1/playback/events",
            json={
                "event_id": str(uuid.uuid4()),
                "track_id": track_two_id,
                "event_type": "PROGRESS_CHECKPOINT",
                "position_ms": 60000,
                "duration_ms": 200000,
                "played_at": (now - timedelta(minutes=5)).isoformat(),
            },
            headers=user1_auth["headers"],
        )

        # Get history
        res = await async_client.get(
            "/api/v1/playback/history?skip=0&limit=10",
            headers=user1_auth["headers"],
        )
        assert res.status_code == 200
        data = res.json()["data"]
        assert data["total"] >= 2
        items = data["items"]
        assert len(items) >= 2

        # Newest played (track 2) should be first
        assert items[0]["track_id"] == track_two_id
        assert items[0]["track"]["title"] == "Midnight Reverie"
        assert items[0]["position_ms"] == 60000

        assert items[1]["track_id"] == track_one_id
        assert items[1]["track"]["title"] == "Acoustic Sun"

        # Verify alias endpoint /api/v1/history
        alias_res = await async_client.get(
            "/api/v1/history",
            headers=user1_auth["headers"],
        )
        assert alias_res.status_code == 200
        assert alias_res.json()["data"]["total"] == data["total"]

    @pytest.mark.asyncio
    async def test_delete_item_and_clear_history(
        self, async_client: AsyncClient, user1_auth, track_one_id, track_two_id
    ):
        # Update progress for both
        await async_client.put(
            f"/api/v1/playback/progress/{track_one_id}",
            json={"position_ms": 10000, "duration_ms": 100000},
            headers=user1_auth["headers"],
        )
        await async_client.put(
            f"/api/v1/playback/progress/{track_two_id}",
            json={"position_ms": 20000, "duration_ms": 100000},
            headers=user1_auth["headers"],
        )

        # Remove single track
        del_item = await async_client.delete(
            f"/api/v1/playback/history/{track_one_id}",
            headers=user1_auth["headers"],
        )
        assert del_item.status_code == 200

        # Check track 1 is gone from history
        h_res = await async_client.get(
            "/api/v1/playback/history",
            headers=user1_auth["headers"],
        )
        items = h_res.json()["data"]["items"]
        assert not any(i["track_id"] == track_one_id for i in items)

        # Clear entire history
        clear_res = await async_client.delete(
            "/api/v1/playback/history",
            headers=user1_auth["headers"],
        )
        assert clear_res.status_code == 200

        # Now history should be empty
        empty_res = await async_client.get(
            "/api/v1/playback/history",
            headers=user1_auth["headers"],
        )
        assert empty_res.json()["data"]["total"] == 0
        assert len(empty_res.json()["data"]["items"]) == 0


class TestMultiUserIsolation:
    @pytest.mark.asyncio
    async def test_user_isolation(
        self, async_client: AsyncClient, user1_auth, user2_auth, track_one_id
    ):
        # User 1 sets progress
        await async_client.put(
            f"/api/v1/playback/progress/{track_one_id}",
            json={"position_ms": 75000, "duration_ms": 150000},
            headers=user1_auth["headers"],
        )

        # User 2 reads progress for same track: should be 0 (isolated)
        u2_res = await async_client.get(
            f"/api/v1/playback/progress/{track_one_id}",
            headers=user2_auth["headers"],
        )
        assert u2_res.status_code == 200
        assert u2_res.json()["data"]["position_ms"] == 0

        # User 2 checks history: should be empty
        u2_hist = await async_client.get(
            "/api/v1/playback/history",
            headers=user2_auth["headers"],
        )
        assert u2_hist.json()["data"]["total"] == 0

    @pytest.mark.asyncio
    async def test_unauthenticated_rejected(
        self, async_client: AsyncClient, track_one_id
    ):
        res = await async_client.get(f"/api/v1/playback/progress/{track_one_id}")
        assert res.status_code == 401

        res_h = await async_client.get("/api/v1/playback/history")
        assert res_h.status_code == 401

        res_ev = await async_client.post(
            "/api/v1/playback/events",
            json={
                "event_id": str(uuid.uuid4()),
                "track_id": track_one_id,
                "event_type": "PLAY_STARTED",
                "position_ms": 0,
                "duration_ms": 100000,
                "played_at": datetime.now(timezone.utc).isoformat(),
            },
        )
        assert res_ev.status_code == 401


class TestRecommendationSignals:
    @pytest.mark.asyncio
    async def test_listening_signals_generation(
        self, db_session: AsyncSession, user1_auth, track_one_id
    ):
        service = PlaybackService(db_session)
        uid = uuid.UUID(user1_auth["user"]["id"])
        tid = uuid.UUID(track_one_id)
        now = datetime.now(timezone.utc)

        # Insert test events directly
        ev1 = PlaybackEvent(
            user_id=uid,
            track_id=tid,
            event_id=uuid.uuid4(),
            event_type="PLAY_STARTED",
            position_ms=0,
            duration_ms=180000,
            source="player",
            played_at=now - timedelta(minutes=5),
        )
        ev2 = PlaybackEvent(
            user_id=uid,
            track_id=tid,
            event_id=uuid.uuid4(),
            event_type="COMPLETED",
            position_ms=180000,
            duration_ms=180000,
            source="player",
            played_at=now,
        )
        prog = TrackPlaybackProgress(
            user_id=uid,
            track_id=tid,
            position_ms=180000,
            duration_ms=180000,
            completed=True,
            created_at=now,
            updated_at=now,
        )
        db_session.add_all([ev1, ev2, prog])
        await db_session.commit()

        signals = await service.get_listening_signals(user_id=uid, limit=10)
        assert len(signals) >= 1
        sig = next(s for s in signals if s.track_id == tid)
        assert sig.play_count >= 2
        assert sig.completion_count >= 1
        assert sig.completed is True
