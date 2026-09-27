import asyncio
import uuid
import pytest
from httpx import AsyncClient

from app.db.database import AsyncSessionLocal
from app.db.models.audio import Track
from app.db.models.user import User
from app.repositories.audio_repository import TrackRepository
from app.repositories.like_repository import LikeRepository
from app.repositories.playlist_repository import PlaylistRepository
from app.services.recommendation.user_preference_service import UserPreferenceService


@pytest.fixture
async def library_user1(async_client: AsyncClient):
    """User 1 fixture."""
    email = f"lib_u1_{uuid.uuid4().hex[:8]}@example.com"
    password = "SecurePassword123!"
    res = await async_client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": password, "name": "Kavya Patel"},
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
async def library_user2(async_client: AsyncClient):
    """User 2 fixture."""
    email = f"lib_u2_{uuid.uuid4().hex[:8]}@example.com"
    password = "SecurePassword123!"
    res = await async_client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": password, "name": "Rohan Mehra"},
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
async def sample_ready_tracks(library_user1):
    """Creates sample READY tracks in the database."""
    tracks = []
    async with AsyncSessionLocal() as session:
        for i in range(3):
            track = Track(
                id=uuid.uuid4(),
                owner_id=library_user1["id"],
                title=f"Sample Track {i + 1}_{uuid.uuid4().hex[:4]}",
                artist_name="Acoustic Dreamer",
                album_name="Golden Hours",
                genre="Acoustic",
                duration_seconds=180 + i * 10,
                status="READY",
                likes_count=0,
            )
            session.add(track)
            tracks.append(track)
        await session.commit()
        for t in tracks:
            await session.refresh(t)

    return tracks


@pytest.mark.asyncio
async def test_like_and_unlike_track_lifecycle(
    async_client: AsyncClient,
    library_user1,
    sample_ready_tracks,
):
    """Tests the full like -> like-status -> unlike lifecycle."""
    track = sample_ready_tracks[0]
    track_id_str = str(track.id)

    # 1. Initial status -> not liked, count 0
    res = await async_client.get(
        f"/api/v1/tracks/{track_id_str}/like-status",
        headers=library_user1["headers"],
    )
    assert res.status_code == 200
    data = res.json()["data"]
    assert data["is_liked"] is False
    assert data["likes_count"] == 0

    # 2. Like track
    res = await async_client.post(
        f"/api/v1/tracks/{track_id_str}/like",
        headers=library_user1["headers"],
    )
    assert res.status_code == 200
    data = res.json()["data"]
    assert data["is_liked"] is True
    assert data["likes_count"] == 1

    # 3. Check like status again
    res = await async_client.get(
        f"/api/v1/tracks/{track_id_str}/like-status",
        headers=library_user1["headers"],
    )
    assert res.status_code == 200
    data = res.json()["data"]
    assert data["is_liked"] is True
    assert data["likes_count"] == 1

    # 4. Unlike track
    res = await async_client.delete(
        f"/api/v1/tracks/{track_id_str}/like",
        headers=library_user1["headers"],
    )
    assert res.status_code == 200
    data = res.json()["data"]
    assert data["is_liked"] is False
    assert data["likes_count"] == 0

    # 5. Check like status after unlike
    res = await async_client.get(
        f"/api/v1/tracks/{track_id_str}/like-status",
        headers=library_user1["headers"],
    )
    assert res.status_code == 200
    data = res.json()["data"]
    assert data["is_liked"] is False
    assert data["likes_count"] == 0


@pytest.mark.asyncio
async def test_like_idempotency_and_no_double_increment(
    async_client: AsyncClient,
    library_user1,
    sample_ready_tracks,
):
    """Tests that repeating a like request does not double increment or fail."""
    track = sample_ready_tracks[0]
    track_id_str = str(track.id)

    # First like
    res1 = await async_client.post(
        f"/api/v1/tracks/{track_id_str}/like",
        headers=library_user1["headers"],
    )
    assert res1.status_code == 200
    assert res1.json()["data"]["likes_count"] == 1

    # Second like (idempotent retry)
    res2 = await async_client.post(
        f"/api/v1/tracks/{track_id_str}/like",
        headers=library_user1["headers"],
    )
    assert res2.status_code == 200
    assert res2.json()["data"]["is_liked"] is True
    assert res2.json()["data"]["likes_count"] == 1


@pytest.mark.asyncio
async def test_unlike_idempotency_and_no_negative_count(
    async_client: AsyncClient,
    library_user1,
    sample_ready_tracks,
):
    """Tests that repeating an unlike request does not decrement below 0."""
    track = sample_ready_tracks[1]
    track_id_str = str(track.id)

    # Unliking a track that was never liked
    res = await async_client.delete(
        f"/api/v1/tracks/{track_id_str}/like",
        headers=library_user1["headers"],
    )
    assert res.status_code == 200
    assert res.json()["data"]["is_liked"] is False
    assert res.json()["data"]["likes_count"] == 0


@pytest.mark.asyncio
async def test_unauthorized_like_rejected(
    async_client: AsyncClient,
    sample_ready_tracks,
):
    """Tests that unauthenticated requests to like endpoints are rejected with 401."""
    track_id_str = str(sample_ready_tracks[0].id)

    res = await async_client.post(f"/api/v1/tracks/{track_id_str}/like")
    assert res.status_code == 401

    res = await async_client.delete(f"/api/v1/tracks/{track_id_str}/like")
    assert res.status_code == 401

    res = await async_client.get(f"/api/v1/tracks/{track_id_str}/like-status")
    assert res.status_code == 401


@pytest.mark.asyncio
async def test_liked_tracks_pagination_and_sorting(
    async_client: AsyncClient,
    library_user1,
    sample_ready_tracks,
):
    """Tests GET /library/liked-tracks with chronological sorting and pagination."""
    track1 = sample_ready_tracks[0]
    track2 = sample_ready_tracks[1]
    track3 = sample_ready_tracks[2]

    # Like tracks with a slight delay to ensure distinct liked_at timestamps
    await async_client.post(f"/api/v1/tracks/{track1.id}/like", headers=library_user1["headers"])
    await asyncio.sleep(0.05)
    await async_client.post(f"/api/v1/tracks/{track2.id}/like", headers=library_user1["headers"])
    await asyncio.sleep(0.05)
    await async_client.post(f"/api/v1/tracks/{track3.id}/like", headers=library_user1["headers"])

    # Page 1, size 2: should return track3 then track2
    res = await async_client.get(
        "/api/v1/library/liked-tracks?page=1&size=2",
        headers=library_user1["headers"],
    )
    assert res.status_code == 200
    data = res.json()["data"]
    assert data["total"] == 3
    assert len(data["items"]) == 2
    assert data["has_next"] is True
    assert data["items"][0]["id"] == str(track3.id)
    assert data["items"][1]["id"] == str(track2.id)

    # Page 2, size 2: should return track1
    res = await async_client.get(
        "/api/v1/library/liked-tracks?page=2&size=2",
        headers=library_user1["headers"],
    )
    assert res.status_code == 200
    data = res.json()["data"]
    assert len(data["items"]) == 1
    assert data["has_next"] is False
    assert data["items"][0]["id"] == str(track1.id)


@pytest.mark.asyncio
async def test_user_isolation_in_personal_library(
    async_client: AsyncClient,
    library_user1,
    library_user2,
    sample_ready_tracks,
):
    """Tests strict user isolation: User 1's likes are never visible to User 2."""
    track1 = sample_ready_tracks[0]
    track2 = sample_ready_tracks[1]

    # User 1 likes track 1
    await async_client.post(f"/api/v1/tracks/{track1.id}/like", headers=library_user1["headers"])

    # User 2 likes track 2
    await async_client.post(f"/api/v1/tracks/{track2.id}/like", headers=library_user2["headers"])

    # User 1's library contains only track 1
    res1 = await async_client.get("/api/v1/library/liked-tracks", headers=library_user1["headers"])
    assert res1.status_code == 200
    items1 = res1.json()["data"]["items"]
    assert len(items1) == 1
    assert items1[0]["id"] == str(track1.id)

    # User 2's library contains only track 2
    res2 = await async_client.get("/api/v1/library/liked-tracks", headers=library_user2["headers"])
    assert res2.status_code == 200
    items2 = res2.json()["data"]["items"]
    assert len(items2) == 1
    assert items2[0]["id"] == str(track2.id)


@pytest.mark.asyncio
async def test_library_summary_endpoint(
    async_client: AsyncClient,
    library_user1,
    sample_ready_tracks,
):
    """Tests GET /library summary endpoint with counts and recent liked preview."""
    track1 = sample_ready_tracks[0]
    track2 = sample_ready_tracks[1]

    await async_client.post(f"/api/v1/tracks/{track1.id}/like", headers=library_user1["headers"])
    await async_client.post(f"/api/v1/tracks/{track2.id}/like", headers=library_user1["headers"])

    res = await async_client.get("/api/v1/library", headers=library_user1["headers"])
    assert res.status_code == 200
    data = res.json()["data"]
    assert data["liked_tracks_count"] == 2
    assert len(data["recent_liked_tracks"]) == 2


@pytest.mark.asyncio
async def test_recommendations_user_preference_service_incorporates_likes(
    library_user1,
    sample_ready_tracks,
):
    """Tests that UserPreferenceService incorporates liked tracks with +3 weight."""
    async with AsyncSessionLocal() as session:
        like_repo = LikeRepository(session)
        playlist_repo = PlaylistRepository(session)
        track_repo = TrackRepository(session)

        # Like track 0
        track = sample_ready_tracks[0]
        await like_repo.like_track(library_user1["id"], track.id)

        user = User(
            id=library_user1["id"],
            email="test_rec@example.com",
            hashed_password="pw",
            username="testrec",
        )

        pref_service = UserPreferenceService(
            playlist_repo=playlist_repo,
            track_repo=track_repo,
            like_repo=like_repo,
        )

        prefs = await pref_service.get_user_preferences(user)
        assert track.genre in prefs.preferred_genres
        assert track.artist_name in prefs.preferred_artists
        assert track.id in prefs.excluded_track_ids
        assert prefs.total_signals >= 6  # 3 from genre, 3 from artist
