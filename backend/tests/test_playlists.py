import io
import uuid
import pytest
from httpx import AsyncClient
from PIL import Image


def create_test_image_bytes(format: str = "PNG", size: tuple = (100, 100), color: str = "blue") -> bytes:
    """Helper to generate a valid in-memory image for cover upload testing."""
    image = Image.new("RGB", size, color=color)
    byte_io = io.BytesIO()
    image.save(byte_io, format=format)
    return byte_io.getvalue()


@pytest.fixture
async def user1_auth(async_client: AsyncClient):
    """Registers and authenticates User 1."""
    email = f"playlist_user1_{uuid.uuid4().hex[:8]}@example.com"
    password = "SecurePassword123!"
    res = await async_client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": password, "name": "User One"},
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
    """Registers and authenticates User 2 for multi-tenant isolation tests."""
    email = f"playlist_user2_{uuid.uuid4().hex[:8]}@example.com"
    password = "SecurePassword123!"
    res = await async_client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": password, "name": "User Two"},
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
async def test_track_id(async_client: AsyncClient, user1_auth):
    """Uploads a test audio track and returns its track_id."""
    # Generate fake MP3 file with ID3 tag
    fake_mp3 = b"ID3\x03\x00\x00\x00\x00\x00\x21" + b"\xFF\xFB\x90\x44" + (b"\x00" * 200)
    files = {"file": ("test_song.mp3", fake_mp3, "audio/mpeg")}
    data = {
        "title": "Acoustic Melody",
        "artist_name": "Sound Artist",
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
async def second_track_id(async_client: AsyncClient, user1_auth):
    """Uploads a second test audio track and returns its track_id."""
    fake_mp3 = b"ID3\x03\x00\x00\x00\x00\x00\x21" + b"\xFF\xFB\x90\x44" + (b"\x00" * 300)
    files = {"file": ("night_fall.mp3", fake_mp3, "audio/mpeg")}
    data = {
        "title": "Nightfall",
        "artist_name": "Sound Artist",
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


class TestPlaylistCRUD:
    async def test_create_playlist_success(self, async_client: AsyncClient, user1_auth):
        headers = user1_auth["headers"]
        payload = {
            "name": "Evening Warmth",
            "description": "Chill acoustic evening playlist",
        }
        res = await async_client.post("/api/v1/playlists", json=payload, headers=headers)
        assert res.status_code == 201
        body = res.json()
        assert body["success"] is True
        data = body["data"]
        assert data["name"] == "Evening Warmth"
        assert data["description"] == "Chill acoustic evening playlist"
        assert data["track_count"] == 0
        assert data["duration_seconds"] == 0
        assert data["owner_id"] == user1_auth["user"]["id"]

    async def test_create_playlist_rejects_empty_name(self, async_client: AsyncClient, user1_auth):
        headers = user1_auth["headers"]
        res = await async_client.post(
            "/api/v1/playlists",
            json={"name": "   ", "description": "Empty"},
            headers=headers,
        )
        assert res.status_code == 422

    async def test_list_playlists_and_isolation(
        self, async_client: AsyncClient, user1_auth, user2_auth
    ):
        # User 1 creates 2 playlists
        await async_client.post(
            "/api/v1/playlists",
            json={"name": "User 1 - Mix A"},
            headers=user1_auth["headers"],
        )
        await async_client.post(
            "/api/v1/playlists",
            json={"name": "User 1 - Mix B"},
            headers=user1_auth["headers"],
        )

        # User 2 creates 1 playlist
        await async_client.post(
            "/api/v1/playlists",
            json={"name": "User 2 - Special"},
            headers=user2_auth["headers"],
        )

        # User 1 lists
        res1 = await async_client.get("/api/v1/playlists", headers=user1_auth["headers"])
        assert res1.status_code == 200
        names1 = [p["name"] for p in res1.json()["data"]]
        assert "User 1 - Mix A" in names1
        assert "User 1 - Mix B" in names1
        assert "User 2 - Special" not in names1

        # User 2 lists
        res2 = await async_client.get("/api/v1/playlists", headers=user2_auth["headers"])
        assert res2.status_code == 200
        names2 = [p["name"] for p in res2.json()["data"]]
        assert "User 2 - Special" in names2
        assert "User 1 - Mix A" not in names2

    async def test_get_playlist_details(self, async_client: AsyncClient, user1_auth):
        res = await async_client.post(
            "/api/v1/playlists",
            json={"name": "Study Vibes"},
            headers=user1_auth["headers"],
        )
        playlist_id = res.json()["data"]["id"]

        detail_res = await async_client.get(
            f"/api/v1/playlists/{playlist_id}",
            headers=user1_auth["headers"],
        )
        assert detail_res.status_code == 200
        detail_data = detail_res.json()["data"]
        assert detail_data["name"] == "Study Vibes"
        assert detail_data["tracks"] == []

    async def test_update_playlist(self, async_client: AsyncClient, user1_auth):
        res = await async_client.post(
            "/api/v1/playlists",
            json={"name": "Original Name", "description": "Original Desc"},
            headers=user1_auth["headers"],
        )
        playlist_id = res.json()["data"]["id"]

        update_res = await async_client.patch(
            f"/api/v1/playlists/{playlist_id}",
            json={"name": "Updated Name", "description": "Updated Desc"},
            headers=user1_auth["headers"],
        )
        assert update_res.status_code == 200
        data = update_res.json()["data"]
        assert data["name"] == "Updated Name"
        assert data["description"] == "Updated Desc"

    async def test_delete_playlist(self, async_client: AsyncClient, user1_auth):
        res = await async_client.post(
            "/api/v1/playlists",
            json={"name": "To Delete"},
            headers=user1_auth["headers"],
        )
        playlist_id = res.json()["data"]["id"]

        del_res = await async_client.delete(
            f"/api/v1/playlists/{playlist_id}",
            headers=user1_auth["headers"],
        )
        assert del_res.status_code == 200

        # Subsequent fetch should be 404
        get_res = await async_client.get(
            f"/api/v1/playlists/{playlist_id}",
            headers=user1_auth["headers"],
        )
        assert get_res.status_code == 404


class TestPlaylistTracks:
    async def test_add_and_remove_tracks(
        self, async_client: AsyncClient, user1_auth, test_track_id, second_track_id
    ):
        # Create playlist
        res = await async_client.post(
            "/api/v1/playlists",
            json={"name": "Track Test Playlist"},
            headers=user1_auth["headers"],
        )
        playlist_id = res.json()["data"]["id"]

        # Add Track 1
        add1_res = await async_client.post(
            f"/api/v1/playlists/{playlist_id}/tracks",
            json={"track_id": test_track_id},
            headers=user1_auth["headers"],
        )
        assert add1_res.status_code == 200
        data1 = add1_res.json()["data"]
        assert len(data1["tracks"]) == 1
        assert data1["tracks"][0]["track_id"] == test_track_id
        assert data1["tracks"][0]["position"] == 0

        # Add Track 2
        add2_res = await async_client.post(
            f"/api/v1/playlists/{playlist_id}/tracks",
            json={"track_id": second_track_id},
            headers=user1_auth["headers"],
        )
        assert add2_res.status_code == 200
        data2 = add2_res.json()["data"]
        assert len(data2["tracks"]) == 2
        assert data2["tracks"][1]["track_id"] == second_track_id
        assert data2["tracks"][1]["position"] == 1

        # Reject duplicate track
        dup_res = await async_client.post(
            f"/api/v1/playlists/{playlist_id}/tracks",
            json={"track_id": test_track_id},
            headers=user1_auth["headers"],
        )
        assert dup_res.status_code == 409

        # Remove Track 1, positions should normalize
        rem_res = await async_client.delete(
            f"/api/v1/playlists/{playlist_id}/tracks/{test_track_id}",
            headers=user1_auth["headers"],
        )
        assert rem_res.status_code == 200
        data_rem = rem_res.json()["data"]
        assert len(data_rem["tracks"]) == 1
        assert data_rem["tracks"][0]["track_id"] == second_track_id
        assert data_rem["tracks"][0]["position"] == 0

    async def test_reorder_tracks(
        self, async_client: AsyncClient, user1_auth, test_track_id, second_track_id
    ):
        res = await async_client.post(
            "/api/v1/playlists",
            json={"name": "Reorder Test"},
            headers=user1_auth["headers"],
        )
        playlist_id = res.json()["data"]["id"]

        # Add both tracks (positions 0, 1)
        await async_client.post(
            f"/api/v1/playlists/{playlist_id}/tracks",
            json={"track_id": test_track_id},
            headers=user1_auth["headers"],
        )
        await async_client.post(
            f"/api/v1/playlists/{playlist_id}/tracks",
            json={"track_id": second_track_id},
            headers=user1_auth["headers"],
        )

        # Reorder to [second_track_id, test_track_id]
        reorder_res = await async_client.patch(
            f"/api/v1/playlists/{playlist_id}/tracks/reorder",
            json={"track_ids": [second_track_id, test_track_id]},
            headers=user1_auth["headers"],
        )
        assert reorder_res.status_code == 200
        reorder_data = reorder_res.json()["data"]
        assert reorder_data["tracks"][0]["track_id"] == second_track_id
        assert reorder_data["tracks"][0]["position"] == 0
        assert reorder_data["tracks"][1]["track_id"] == test_track_id
        assert reorder_data["tracks"][1]["position"] == 1

    async def test_reorder_rejects_mismatched_track_ids(
        self, async_client: AsyncClient, user1_auth, test_track_id
    ):
        res = await async_client.post(
            "/api/v1/playlists",
            json={"name": "Reorder Mismatch"},
            headers=user1_auth["headers"],
        )
        playlist_id = res.json()["data"]["id"]

        await async_client.post(
            f"/api/v1/playlists/{playlist_id}/tracks",
            json={"track_id": test_track_id},
            headers=user1_auth["headers"],
        )

        # Submit random uuid
        bad_res = await async_client.patch(
            f"/api/v1/playlists/{playlist_id}/tracks/reorder",
            json={"track_ids": [str(uuid.uuid4())]},
            headers=user1_auth["headers"],
        )
        assert bad_res.status_code == 400


class TestPlaylistOwnershipAndSecurity:
    async def test_user_cannot_access_or_modify_other_user_playlist(
        self, async_client: AsyncClient, user1_auth, user2_auth, test_track_id
    ):
        # User 1 creates playlist
        res = await async_client.post(
            "/api/v1/playlists",
            json={"name": "User 1 Private"},
            headers=user1_auth["headers"],
        )
        playlist_id = res.json()["data"]["id"]

        # User 2 tries to get
        get_res = await async_client.get(
            f"/api/v1/playlists/{playlist_id}",
            headers=user2_auth["headers"],
        )
        assert get_res.status_code == 403

        # User 2 tries to update
        patch_res = await async_client.patch(
            f"/api/v1/playlists/{playlist_id}",
            json={"name": "Hacked"},
            headers=user2_auth["headers"],
        )
        assert patch_res.status_code == 403

        # User 2 tries to add track
        add_res = await async_client.post(
            f"/api/v1/playlists/{playlist_id}/tracks",
            json={"track_id": test_track_id},
            headers=user2_auth["headers"],
        )
        assert add_res.status_code == 403

        # User 2 tries to delete
        del_res = await async_client.delete(
            f"/api/v1/playlists/{playlist_id}",
            headers=user2_auth["headers"],
        )
        assert del_res.status_code == 403

    async def test_unauthenticated_rejected(self, async_client: AsyncClient):
        res = await async_client.get("/api/v1/playlists")
        assert res.status_code == 401


class TestPlaylistCover:
    async def test_upload_and_remove_cover(
        self, async_client: AsyncClient, user1_auth
    ):
        res = await async_client.post(
            "/api/v1/playlists",
            json={"name": "Cover Art Playlist"},
            headers=user1_auth["headers"],
        )
        playlist_id = res.json()["data"]["id"]

        # Upload cover image
        image_bytes = create_test_image_bytes("PNG")
        files = {"file": ("cover.png", image_bytes, "image/png")}
        upload_res = await async_client.post(
            f"/api/v1/playlists/{playlist_id}/cover",
            files=files,
            headers=user1_auth["headers"],
        )
        assert upload_res.status_code == 200
        data = upload_res.json()["data"]
        assert data["cover_image_key"] is not None
        assert data["cover_image_url"] is not None

        # Remove cover
        rem_res = await async_client.delete(
            f"/api/v1/playlists/{playlist_id}/cover",
            headers=user1_auth["headers"],
        )
        assert rem_res.status_code == 200
        rem_data = rem_res.json()["data"]
        assert rem_data["cover_image_key"] is None
        assert rem_data["cover_image_url"] is None
