import io
import uuid
import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from PIL import Image

from app.db.models.user import User
from app.db.models.creator import Creator
from app.db.models.audio import Track, AudioFile, AudioRendition, ProcessingJob
from app.db.models.admin import AdminAuditLog


@pytest.fixture
async def creator_user(async_client: AsyncClient, db_session: AsyncSession) -> dict:
    email = f"creator_{uuid.uuid4().hex[:8]}@example.com"
    res = await async_client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": "Password123!", "name": "Main Creator"},
    )
    assert res.status_code == 201
    data = res.json()["data"]
    user_id = uuid.UUID(data["user"]["id"])

    result = await db_session.execute(select(User).where(User.id == user_id))
    user = result.scalar_one()
    user.role = "creator"

    creator_entity = Creator(
        id=uuid.uuid4(),
        user_id=user_id,
        name="Main Creator",
        bio="Primary creator bio",
    )
    db_session.add(creator_entity)
    await db_session.commit()

    login_res = await async_client.post(
        "/api/v1/auth/login",
        json={"email": email, "password": "Password123!"},
    )
    assert login_res.status_code == 200
    token = login_res.json()["data"]["access_token"]

    return {
        "headers": {"Authorization": f"Bearer {token}"},
        "user_id": user_id,
        "creator_id": creator_entity.id,
        "email": email,
    }


@pytest.fixture
async def other_creator(async_client: AsyncClient, db_session: AsyncSession) -> dict:
    email = f"other_{uuid.uuid4().hex[:8]}@example.com"
    res = await async_client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": "Password123!", "name": "Other Creator"},
    )
    assert res.status_code == 201
    data = res.json()["data"]
    user_id = uuid.UUID(data["user"]["id"])

    result = await db_session.execute(select(User).where(User.id == user_id))
    user = result.scalar_one()
    user.role = "creator"

    creator_entity = Creator(
        id=uuid.uuid4(),
        user_id=user_id,
        name="Other Creator",
        bio="Other creator bio",
    )
    db_session.add(creator_entity)
    await db_session.commit()

    login_res = await async_client.post(
        "/api/v1/auth/login",
        json={"email": email, "password": "Password123!"},
    )
    assert login_res.status_code == 200
    token = login_res.json()["data"]["access_token"]

    return {
        "headers": {"Authorization": f"Bearer {token}"},
        "user_id": user_id,
        "creator_id": creator_entity.id,
        "email": email,
    }


@pytest.fixture
async def admin_user(async_client: AsyncClient, db_session: AsyncSession) -> dict:
    email = f"admin_{uuid.uuid4().hex[:8]}@example.com"
    res = await async_client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": "Password123!", "name": "Admin User"},
    )
    assert res.status_code == 201
    data = res.json()["data"]
    user_id = uuid.UUID(data["user"]["id"])

    result = await db_session.execute(select(User).where(User.id == user_id))
    user = result.scalar_one()
    user.role = "admin"
    await db_session.commit()

    login_res = await async_client.post(
        "/api/v1/auth/login",
        json={"email": email, "password": "Password123!"},
    )
    assert login_res.status_code == 200
    token = login_res.json()["data"]["access_token"]

    return {
        "headers": {"Authorization": f"Bearer {token}"},
        "user_id": user_id,
        "email": email,
    }


@pytest.fixture
async def sample_tracks(db_session: AsyncSession, creator_user: dict, other_creator: dict) -> list[Track]:
    """Creates a sample set of tracks in various states with renditions and jobs."""
    c1_id = creator_user["user_id"]
    c2_id = other_creator["user_id"]

    # Track 1: Ready & Published (Creator 1)
    t1 = Track(
        id=uuid.uuid4(),
        owner_id=c1_id,
        creator_id=creator_user["creator_id"],
        title="Midnight Echoes",
        artist_name="Main Creator",
        album_name="Nocturne",
        genre="Ambient",
        status="READY",
        is_published=True,
        duration_seconds=210,
    )
    db_session.add(t1)

    r1 = AudioRendition(
        id=uuid.uuid4(),
        track_id=t1.id,
        bitrate_kbps=320,
        format="mp3",
        codec="libmp3lame",
        file_size_bytes=8400000,
        storage_key=f"audio/renditions/{t1.id}/high.mp3",
    )
    db_session.add(r1)

    j1 = ProcessingJob(
        id=uuid.uuid4(),
        track_id=t1.id,
        job_type="transcode",
        status="COMPLETED",
        attempts=1,
    )
    db_session.add(j1)

    # Track 2: Processing (Creator 1, is_published=False)
    t2 = Track(
        id=uuid.uuid4(),
        owner_id=c1_id,
        creator_id=creator_user["creator_id"],
        title="Daylight Beats",
        artist_name="Main Creator",
        genre="Electronic",
        status="PROCESSING",
        is_published=False,
        duration_seconds=180,
    )
    db_session.add(t2)

    # Track 3: Failed (Creator 1)
    t3 = Track(
        id=uuid.uuid4(),
        owner_id=c1_id,
        creator_id=creator_user["creator_id"],
        title="Distorted Static",
        artist_name="Main Creator",
        genre="Noise",
        status="FAILED",
        is_published=False,
        duration_seconds=90,
    )
    db_session.add(t3)

    j3 = ProcessingJob(
        id=uuid.uuid4(),
        track_id=t3.id,
        job_type="transcode",
        status="FAILED",
        attempts=3,
        error_message="Audio decoding failed: invalid stream header",
    )
    db_session.add(j3)

    # Track 4: Ready (Other Creator)
    t4 = Track(
        id=uuid.uuid4(),
        owner_id=c2_id,
        creator_id=other_creator["creator_id"],
        title="Other Artist Track",
        artist_name="Other Creator",
        genre="Ambient",
        status="READY",
        is_published=True,
        duration_seconds=240,
    )
    db_session.add(t4)

    await db_session.commit()
    return [t1, t2, t3, t4]


# ============================================================================
# Creator Media Library Tests
# ============================================================================

@pytest.mark.asyncio
async def test_creator_list_tracks_filtering_and_sorting(
    async_client: AsyncClient, creator_user: dict, sample_tracks: list[Track]
):
    """Verifies creator only sees own tracks, and filters/sorts work correctly."""
    headers = creator_user["headers"]

    # 1. Base list: Creator 1 has 3 tracks (t1, t2, t3), NOT t4
    res = await async_client.get("/api/v1/creator-studio/tracks", headers=headers)
    assert res.status_code == 200
    data = res.json()["data"]
    assert data["total"] == 3
    track_ids = [t["id"] for t in data["items"]]
    assert str(sample_tracks[3].id) not in track_ids

    # 2. Filter by status: READY
    res_ready = await async_client.get(
        "/api/v1/creator-studio/tracks?status=READY", headers=headers
    )
    assert res_ready.status_code == 200
    ready_items = res_ready.json()["data"]["items"]
    assert len(ready_items) == 1
    assert ready_items[0]["title"] == "Midnight Echoes"

    # 3. Filter by is_published: false
    res_unpub = await async_client.get(
        "/api/v1/creator-studio/tracks?is_published=false", headers=headers
    )
    assert res_unpub.status_code == 200
    unpub_items = res_unpub.json()["data"]["items"]
    assert len(unpub_items) == 2

    # 4. Filter by genre
    res_genre = await async_client.get(
        "/api/v1/creator-studio/tracks?genre=Ambient", headers=headers
    )
    assert res_genre.status_code == 200
    genre_items = res_genre.json()["data"]["items"]
    assert len(genre_items) == 1
    assert genre_items[0]["genre"] == "Ambient"

    # 5. Search
    res_search = await async_client.get(
        "/api/v1/creator-studio/tracks?search=Midnight", headers=headers
    )
    assert res_search.status_code == 200
    assert len(res_search.json()["data"]["items"]) == 1

    # 6. Sorting by duration_seconds desc
    res_sort = await async_client.get(
        "/api/v1/creator-studio/tracks?sort_by=duration_seconds&sort_order=desc", headers=headers
    )
    assert res_sort.status_code == 200
    sorted_items = res_sort.json()["data"]["items"]
    assert sorted_items[0]["title"] == "Midnight Echoes"


@pytest.mark.asyncio
async def test_creator_track_detail_with_renditions_and_jobs(
    async_client: AsyncClient, creator_user: dict, sample_tracks: list[Track]
):
    """Verifies track detail returns audio renditions, processing jobs, and ownership checks."""
    headers = creator_user["headers"]
    t1 = sample_tracks[0]

    # Creator gets own track detail
    res = await async_client.get(f"/api/v1/creator-studio/tracks/{t1.id}", headers=headers)
    assert res.status_code == 200
    data = res.json()["data"]
    assert data["id"] == str(t1.id)
    assert data["title"] == "Midnight Echoes"
    assert len(data["renditions"]) == 1
    assert data["renditions"][0]["bitrate_kbps"] == 320
    assert data["renditions"][0]["format"] == "mp3"
    assert len(data["processing_jobs"]) == 1
    assert data["processing_jobs"][0]["status"] == "COMPLETED"

    # Failed track has error message in job
    t3 = sample_tracks[2]
    res3 = await async_client.get(f"/api/v1/creator-studio/tracks/{t3.id}", headers=headers)
    assert res3.status_code == 200
    jobs3 = res3.json()["data"]["processing_jobs"]
    assert len(jobs3) == 1
    assert "invalid stream header" in jobs3[0]["error_message"]


@pytest.mark.asyncio
async def test_creator_ownership_isolation(
    async_client: AsyncClient, creator_user: dict, other_creator: dict, sample_tracks: list[Track]
):
    """Ensures a creator cannot access or modify tracks belonging to another creator."""
    other_headers = other_creator["headers"]
    t1 = sample_tracks[0]  # Owned by creator_user

    # GET detail should 404 (not found in user's catalog)
    res_get = await async_client.get(f"/api/v1/creator-studio/tracks/{t1.id}", headers=other_headers)
    assert res_get.status_code == 404

    # PATCH metadata should 404
    res_patch = await async_client.patch(
        f"/api/v1/creator-studio/tracks/{t1.id}",
        json={"title": "Hacked Title"},
        headers=other_headers,
    )
    assert res_patch.status_code == 404

    # PATCH publishing should 404
    res_pub = await async_client.patch(
        f"/api/v1/creator-studio/tracks/{t1.id}/publishing",
        json={"is_published": False},
        headers=other_headers,
    )
    assert res_pub.status_code == 404

    # POST retry should 404
    res_retry = await async_client.post(
        f"/api/v1/creator-studio/tracks/{t1.id}/retry",
        headers=other_headers,
    )
    assert res_retry.status_code == 404


@pytest.mark.asyncio
async def test_publishing_lifecycle_rules(
    async_client: AsyncClient, creator_user: dict, sample_tracks: list[Track]
):
    """Verifies that publishing requires READY status, and unpublishing works freely."""
    headers = creator_user["headers"]
    t1 = sample_tracks[0]  # READY
    t2 = sample_tracks[1]  # PROCESSING

    # 1. Attempt to publish PROCESSING track -> must fail with 400
    res_fail = await async_client.patch(
        f"/api/v1/creator-studio/tracks/{t2.id}/publishing",
        json={"is_published": True},
        headers=headers,
    )
    assert res_fail.status_code == 400
    assert "TRACK_NOT_READY_FOR_PUBLISHING" in res_fail.json()["error"]["code"]

    # 2. Unpublish READY track -> succeeds
    res_unpub = await async_client.patch(
        f"/api/v1/creator-studio/tracks/{t1.id}/publishing",
        json={"is_published": False},
        headers=headers,
    )
    assert res_unpub.status_code == 200
    assert res_unpub.json()["data"]["is_published"] is False

    # 3. Re-publish READY track -> succeeds
    res_repub = await async_client.patch(
        f"/api/v1/creator-studio/tracks/{t1.id}/publishing",
        json={"is_published": True},
        headers=headers,
    )
    assert res_repub.status_code == 200
    assert res_repub.json()["data"]["is_published"] is True


@pytest.mark.asyncio
async def test_creator_bulk_actions(
    async_client: AsyncClient, creator_user: dict, other_creator: dict, sample_tracks: list[Track]
):
    """Tests creator bulk action with mixed ownership and state validation."""
    headers = creator_user["headers"]
    t1 = sample_tracks[0]  # Ready
    t2 = sample_tracks[1]  # Processing
    t4 = sample_tracks[3]  # Other creator

    # Bulk publish: t1 (ready -> success), t2 (processing -> fails: not ready), t4 (other creator -> fails: not found)
    payload = {
        "action": "publish",
        "track_ids": [str(t1.id), str(t2.id), str(t4.id)],
    }
    res = await async_client.post(
        "/api/v1/creator-studio/tracks/bulk-action",
        json=payload,
        headers=headers,
    )
    assert res.status_code == 200
    data = res.json()["data"]
    assert data["total"] == 3
    assert data["succeeded"] == 1
    assert data["failed"] == 2

    # Verify per-item outcomes
    results_by_id = {r["track_id"]: r for r in data["results"]}
    assert results_by_id[str(t1.id)]["status"] == "success"
    assert results_by_id[str(t2.id)]["status"] == "failed"
    assert "Must be READY" in results_by_id[str(t2.id)]["error"]
    assert results_by_id[str(t4.id)]["status"] == "failed"
    assert "not found" in results_by_id[str(t4.id)]["error"]

    # Bulk unpublish t1
    unpub_payload = {
        "action": "unpublish",
        "track_ids": [str(t1.id)],
    }
    res_unpub = await async_client.post(
        "/api/v1/creator-studio/tracks/bulk-action",
        json=unpub_payload,
        headers=headers,
    )
    assert res_unpub.status_code == 200
    assert res_unpub.json()["data"]["succeeded"] == 1

    # Bulk update genre
    genre_payload = {
        "action": "update_metadata",
        "track_ids": [str(t1.id)],
        "genre": "Synthwave",
    }
    res_meta = await async_client.post(
        "/api/v1/creator-studio/tracks/bulk-action",
        json=genre_payload,
        headers=headers,
    )
    assert res_meta.status_code == 200
    assert res_meta.json()["data"]["succeeded"] == 1


@pytest.mark.asyncio
async def test_artwork_upload_validation(
    async_client: AsyncClient, creator_user: dict, sample_tracks: list[Track]
):
    """Tests artwork upload validation: rejects invalid MIME and file types."""
    headers = creator_user["headers"]
    t1 = sample_tracks[0]

    # 1. Invalid mime type (text file disguised)
    fake_txt = io.BytesIO(b"this is not an image")
    res_bad = await async_client.post(
        f"/api/v1/creator-studio/tracks/{t1.id}/artwork",
        files={"file": ("artwork.txt", fake_txt, "text/plain")},
        headers=headers,
    )
    assert res_bad.status_code == 400

    # 2. Valid image (PNG)
    img = Image.new("RGB", (300, 300), color=(73, 109, 137))
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    buf.seek(0)

    res_good = await async_client.post(
        f"/api/v1/creator-studio/tracks/{t1.id}/artwork",
        files={"file": ("cover.png", buf, "image/png")},
        headers=headers,
    )
    assert res_good.status_code == 200
    art_data = res_good.json()["data"]
    assert "cover_image_key" in art_data
    assert "cover_image_url" in art_data
    assert art_data["cover_image_key"].startswith(f"artwork/tracks/{t1.id}/")


# ============================================================================
# Admin Management & Moderation Tests
# ============================================================================

@pytest.mark.asyncio
async def test_admin_tracks_catalog_and_bulk_moderation(
    async_client: AsyncClient, admin_user: dict, sample_tracks: list[Track], db_session: AsyncSession
):
    """Tests administrative tracks listing, detail with audit logs, and bulk moderation."""
    headers = admin_user["headers"]
    t1 = sample_tracks[0]
    t2 = sample_tracks[1]

    # 1. Admin lists all tracks (should see all 4 across all creators)
    res = await async_client.get("/api/v1/admin/tracks", headers=headers)
    assert res.status_code == 200
    data = res.json()["data"]
    assert data["total"] >= 4

    # 2. Admin filters by genre
    res_genre = await async_client.get("/api/v1/admin/tracks?genre=Ambient", headers=headers)
    assert res_genre.status_code == 200
    assert len(res_genre.json()["data"]["items"]) >= 2

    # 3. Admin gets track detail with audit logs
    res_det = await async_client.get(f"/api/v1/admin/tracks/{t1.id}", headers=headers)
    assert res_det.status_code == 200
    det = res_det.json()["data"]
    assert det["id"] == str(t1.id)
    assert "audit_logs" in det

    # 4. Admin bulk moderation: moderate status to MODERATED
    bulk_payload = {
        "action": "moderate",
        "track_ids": [str(t1.id), str(t2.id)],
        "target_status": "MODERATED",
        "reason": "Copyright dispute investigation",
    }
    res_bulk = await async_client.post(
        "/api/v1/admin/tracks/bulk-action",
        json=bulk_payload,
        headers=headers,
    )
    assert res_bulk.status_code == 200
    bulk_data = res_bulk.json()["data"]
    assert bulk_data["succeeded"] == 2

    # 5. Verify audit logs were written
    log_res = await db_session.execute(
        select(AdminAuditLog).where(
            AdminAuditLog.action == "BULK_TRACK_MODERATE",
            AdminAuditLog.target_type == "track_bulk",
        ).order_by(AdminAuditLog.created_at.desc())
    )
    logs = log_res.scalars().all()
    assert len(logs) >= 1
    latest_log = logs[0]
    assert str(t1.id) in latest_log.target_id
    assert str(t2.id) in latest_log.target_id
