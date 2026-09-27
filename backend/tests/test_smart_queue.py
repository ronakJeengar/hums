import uuid
import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models.audio import Track


@pytest.fixture
async def user_auth(async_client: AsyncClient):
    """Registers and authenticates a test user."""
    email = f"queue_user_{uuid.uuid4().hex[:8]}@example.com"
    password = "SecurePassword123!"
    res = await async_client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": password, "name": "Queue User"},
    )
    assert res.status_code == 201
    data = res.json()["data"]
    token = data["access_token"]
    return {
        "access_token": token,
        "headers": {"Authorization": f"Bearer {token}"},
        "user_id": uuid.UUID(data["user"]["id"]),
        "user": data["user"],
    }


@pytest.fixture
async def sample_tracks(db_session: AsyncSession, user_auth):
    """Creates a set of READY tracks for smart queue testing."""
    tracks = []
    genres = ["Lo-Fi", "Lo-Fi", "Electronic", "Acoustic", "Jazz"]
    artists = ["Artist Alpha", "Artist Alpha", "Artist Beta", "Artist Gamma", "Artist Delta"]
    owner_id = user_auth["user_id"]

    for i in range(5):
        t = Track(
            id=uuid.uuid4(),
            owner_id=owner_id,
            title=f"Queue Track {i + 1}",
            artist_name=artists[i],
            album_name=f"Album {i + 1}",
            genre=genres[i],
            duration_seconds=180 + i * 10,
            status="READY",
            waveform_key=f"waveforms/track_{i+1}.json",
        )
        db_session.add(t)
        tracks.append(t)

    await db_session.commit()
    return tracks


@pytest.mark.asyncio
async def test_get_up_next_anonymous_returns_ready_tracks(
    async_client: AsyncClient, sample_tracks
):
    """Anonymous user should receive smart queue candidates without errors."""
    res = await async_client.get("/api/v1/player/up-next?limit=3")
    assert res.status_code == 200
    payload = res.json()
    assert payload["success"] is True
    data = payload["data"]
    assert len(data["items"]) <= 3
    assert data["total"] == len(data["items"])
    for item in data["items"]:
        assert item["status"] == "READY"
        assert item["id"] is not None
        assert item["title"] is not None


@pytest.mark.asyncio
async def test_get_up_next_with_current_track_context(
    async_client: AsyncClient, sample_tracks
):
    """When current_track_id is supplied, it is excluded and recommendations prioritize its genre/artist."""
    curr = sample_tracks[0]  # Lo-Fi by Artist Alpha
    res = await async_client.get(f"/api/v1/player/up-next?current_track_id={curr.id}&limit=4")
    assert res.status_code == 200
    data = res.json()["data"]

    # Current track should NOT be in up-next items
    returned_ids = [item["id"] for item in data["items"]]
    assert str(curr.id) not in returned_ids

    # Should match context
    assert "similar_to" in data["context"]
    # Lo-Fi track 2 should be in candidates
    sources = [item["source"] for item in data["items"]]
    assert any("genre_match" in s or "artist_match" in s for s in sources)


@pytest.mark.asyncio
async def test_get_up_next_excludes_specified_tracks(
    async_client: AsyncClient, sample_tracks
):
    """Explicitly excluded track IDs must not be included in candidate recommendations."""
    exclude_t1 = sample_tracks[0]
    exclude_t2 = sample_tracks[1]
    exclude_str = f"{exclude_t1.id},{exclude_t2.id}"

    res = await async_client.get(f"/api/v1/player/up-next?exclude_ids={exclude_str}&limit=10")
    assert res.status_code == 200
    returned_ids = [item["id"] for item in res.json()["data"]["items"]]
    assert str(exclude_t1.id) not in returned_ids
    assert str(exclude_t2.id) not in returned_ids


@pytest.mark.asyncio
async def test_get_up_next_invalid_exclusion_uuid_fails(async_client: AsyncClient):
    """Invalid UUID format in exclude_ids returns 400 Bad Request."""
    res = await async_client.get("/api/v1/player/up-next?exclude_ids=not-a-valid-uuid")
    assert res.status_code == 400
    assert res.json()["error"]["code"] == "INVALID_UUID"


@pytest.mark.asyncio
async def test_get_up_next_excessive_exclusions_fails(async_client: AsyncClient):
    """More than 100 exclusions returns 400 Bad Request."""
    excessive_uuids = ",".join([str(uuid.uuid4()) for _ in range(101)])
    res = await async_client.get(f"/api/v1/player/up-next?exclude_ids={excessive_uuids}")
    assert res.status_code == 400
    assert res.json()["error"]["code"] == "EXCESSIVE_EXCLUSION_SIZE"


@pytest.mark.asyncio
async def test_resolve_tracks_batch(async_client: AsyncClient, sample_tracks):
    """Resolves metadata for a comma-separated list of valid track UUIDs."""
    t1 = sample_tracks[0]
    t2 = sample_tracks[2]
    ids_str = f"{t1.id},{t2.id}"

    res = await async_client.get(f"/api/v1/player/resolve?track_ids={ids_str}")
    assert res.status_code == 200
    data = res.json()["data"]
    items = data["items"]
    assert len(items) == 2
    assert {i["id"] for i in items} == {str(t1.id), str(t2.id)}
    assert items[0]["title"] in [t1.title, t2.title]


@pytest.mark.asyncio
async def test_resolve_tracks_excessive_batch(async_client: AsyncClient):
    """More than 100 track IDs returns 400 Bad Request."""
    excessive_uuids = ",".join([str(uuid.uuid4()) for _ in range(101)])
    res = await async_client.get(f"/api/v1/player/resolve?track_ids={excessive_uuids}")
    assert res.status_code == 400
    assert res.json()["error"]["code"] == "EXCESSIVE_BATCH_SIZE"


@pytest.mark.asyncio
async def test_playback_queue_alias_router(async_client: AsyncClient, sample_tracks):
    """Verify that alias endpoint /api/v1/playback/queue/up-next functions identically."""
    res = await async_client.get("/api/v1/playback/queue/up-next?limit=2")
    assert res.status_code == 200
    assert res.json()["success"] is True
    assert len(res.json()["data"]["items"]) <= 2
