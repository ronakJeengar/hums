import uuid
import pytest
from httpx import AsyncClient


def create_mock_mp3_bytes() -> bytes:
    """Returns valid mock MP3 byte sequence with ID3 header."""
    return b"ID3\x03\x00\x00\x00\x00\x00\x00" + b"\x00" * 200


def create_mock_wav_bytes() -> bytes:
    """Returns valid mock WAV byte sequence with RIFF...WAVE headers."""
    header = (
        b"RIFF"
        + (200).to_bytes(4, "little")
        + b"WAVE"
        + b"fmt "
        + (16).to_bytes(4, "little")
        + b"\x01\x00\x02\x00\x44\xac\x00\x00\x10\xb1\x02\x00\x04\x00\x10\x00"
        + b"data"
        + (100).to_bytes(4, "little")
    )
    return header + b"\x00" * 100


def create_mock_flac_bytes() -> bytes:
    """Returns valid mock FLAC byte sequence with fLaC header."""
    return b"fLaC\x00\x00\x00\x22" + b"\x00" * 200


def create_mock_ogg_bytes() -> bytes:
    """Returns valid mock OGG byte sequence with OggS header."""
    return b"OggS\x00\x02\x00\x00\x00\x00\x00\x00\x00\x00" + b"\x00" * 200


def create_mock_m4a_bytes() -> bytes:
    """Returns valid mock M4A byte sequence with ftyp header."""
    return b"\x00\x00\x00\x20ftypM4A \x00\x00\x00\x00M4A mp42isom" + b"\x00" * 200


@pytest.fixture
async def user_a_tokens(async_client: AsyncClient):
    """Registers and authenticates User A."""
    email = f"user_a_{uuid.uuid4().hex[:8]}@example.com"
    password = "SecurePassword123!"
    res = await async_client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": password, "name": "Artist A"},
    )
    assert res.status_code == 201
    data = res.json()["data"]
    return {
        "access_token": data["access_token"],
        "headers": {"Authorization": f"Bearer {data['access_token']}"},
        "user": data["user"],
        "email": email,
    }


@pytest.fixture
async def user_b_tokens(async_client: AsyncClient):
    """Registers and authenticates User B for isolation checks."""
    email = f"user_b_{uuid.uuid4().hex[:8]}@example.com"
    password = "SecurePassword123!"
    res = await async_client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": password, "name": "Artist B"},
    )
    assert res.status_code == 201
    data = res.json()["data"]
    return {
        "access_token": data["access_token"],
        "headers": {"Authorization": f"Bearer {data['access_token']}"},
        "user": data["user"],
        "email": email,
    }


class TestAudioValidation:
    async def test_upload_too_small_file_fails(
        self, async_client: AsyncClient, user_a_tokens
    ):
        headers = user_a_tokens["headers"]
        response = await async_client.post(
            "/api/v1/audio/upload",
            headers=headers,
            data={"title": "Tiny Track"},
            files={"file": ("tiny.mp3", b"ID3\x00\x00", "audio/mpeg")},
        )
        assert response.status_code == 400
        body = response.json()
        assert body["success"] is False
        assert body["error"]["code"] == "INVALID_AUDIO_FILE"

    async def test_upload_invalid_magic_bytes_fails(
        self, async_client: AsyncClient, user_a_tokens
    ):
        headers = user_a_tokens["headers"]
        # Plain text file disguised as mp3
        fake_audio = b"This is plain text and definitely not an audio file." * 10
        response = await async_client.post(
            "/api/v1/audio/upload",
            headers=headers,
            data={"title": "Fake Track"},
            files={"file": ("fake.mp3", fake_audio, "audio/mpeg")},
        )
        assert response.status_code == 400
        body = response.json()
        assert body["success"] is False
        assert body["error"]["code"] == "INVALID_AUDIO_FORMAT"

    async def test_upload_missing_title_fails(
        self, async_client: AsyncClient, user_a_tokens
    ):
        headers = user_a_tokens["headers"]
        mp3_bytes = create_mock_mp3_bytes()
        response = await async_client.post(
            "/api/v1/audio/upload",
            headers=headers,
            data={},
            files={"file": ("song.mp3", mp3_bytes, "audio/mpeg")},
        )
        assert response.status_code in (400, 422)
        assert response.json()["success"] is False

    async def test_upload_unauthenticated_fails(self, async_client: AsyncClient):
        mp3_bytes = create_mock_mp3_bytes()
        response = await async_client.post(
            "/api/v1/audio/upload",
            data={"title": "Unauthenticated Track"},
            files={"file": ("song.mp3", mp3_bytes, "audio/mpeg")},
        )
        assert response.status_code == 401
        assert response.json()["success"] is False


class TestAudioUploadSuccess:
    async def test_upload_mp3_success(
        self, async_client: AsyncClient, user_a_tokens
    ):
        headers = user_a_tokens["headers"]
        mp3_bytes = create_mock_mp3_bytes()
        response = await async_client.post(
            "/api/v1/audio/upload",
            headers=headers,
            data={
                "title": "Midnight Hums",
                "artist_name": "Acoustic Wonder",
                "album_name": "Night Sessions",
                "genre": "Ambient",
                "description": "A relaxing midnight acoustic session.",
            },
            files={"file": ("midnight.mp3", mp3_bytes, "audio/mpeg")},
        )
        assert response.status_code == 201
        body = response.json()
        assert body["success"] is True
        track = body["data"]
        assert track["title"] == "Midnight Hums"
        assert track["artist_name"] == "Acoustic Wonder"
        assert track["album_name"] == "Night Sessions"
        assert track["genre"] == "Ambient"
        assert track["status"] == "UPLOADED"
        assert track["owner_id"] == user_a_tokens["user"]["id"]

        # Check audio files
        assert len(track["audio_files"]) == 1
        audio_file = track["audio_files"][0]
        assert audio_file["mime_type"] == "audio/mpeg"
        assert audio_file["file_size_bytes"] == len(mp3_bytes)
        assert "audio/original/" in audio_file["object_key"]

        # Check processing jobs
        assert len(track["processing_jobs"]) == 1
        job = track["processing_jobs"][0]
        assert job["job_type"] == "AUDIO_TRANSCODE"
        assert job["status"] == "PENDING"
        assert job["attempts"] == 0

    async def test_upload_wav_success(
        self, async_client: AsyncClient, user_a_tokens
    ):
        headers = user_a_tokens["headers"]
        wav_bytes = create_mock_wav_bytes()
        response = await async_client.post(
            "/api/v1/audio/upload",
            headers=headers,
            data={"title": "Studio WAV Master"},
            files={"file": ("master.wav", wav_bytes, "audio/wav")},
        )
        assert response.status_code == 201
        body = response.json()
        assert body["success"] is True
        assert body["data"]["audio_files"][0]["mime_type"] == "audio/wav"

    async def test_upload_flac_success(
        self, async_client: AsyncClient, user_a_tokens
    ):
        headers = user_a_tokens["headers"]
        flac_bytes = create_mock_flac_bytes()
        response = await async_client.post(
            "/api/v1/audio/upload",
            headers=headers,
            data={"title": "Lossless Master"},
            files={"file": ("lossless.flac", flac_bytes, "audio/flac")},
        )
        assert response.status_code == 201
        body = response.json()
        assert body["success"] is True
        assert body["data"]["audio_files"][0]["mime_type"] == "audio/flac"


class TestAudioTracksListingAndIsolation:
    async def test_list_tracks_and_isolation(
        self, async_client: AsyncClient, user_a_tokens, user_b_tokens
    ):
        # User A uploads 2 tracks
        mp3_bytes = create_mock_mp3_bytes()
        await async_client.post(
            "/api/v1/audio/upload",
            headers=user_a_tokens["headers"],
            data={"title": "Track A1"},
            files={"file": ("a1.mp3", mp3_bytes, "audio/mpeg")},
        )
        await async_client.post(
            "/api/v1/audio/upload",
            headers=user_a_tokens["headers"],
            data={"title": "Track A2"},
            files={"file": ("a2.mp3", mp3_bytes, "audio/mpeg")},
        )

        # User B uploads 1 track
        await async_client.post(
            "/api/v1/audio/upload",
            headers=user_b_tokens["headers"],
            data={"title": "Track B1"},
            files={"file": ("b1.mp3", mp3_bytes, "audio/mpeg")},
        )

        # User A lists tracks
        res_a = await async_client.get(
            "/api/v1/audio/tracks", headers=user_a_tokens["headers"]
        )
        assert res_a.status_code == 200
        tracks_a = res_a.json()["data"]
        titles_a = [t["title"] for t in tracks_a]
        assert "Track A1" in titles_a
        assert "Track A2" in titles_a
        assert "Track B1" not in titles_a

        # User B lists tracks
        res_b = await async_client.get(
            "/api/v1/audio/tracks", headers=user_b_tokens["headers"]
        )
        assert res_b.status_code == 200
        tracks_b = res_b.json()["data"]
        titles_b = [t["title"] for t in tracks_b]
        assert "Track B1" in titles_b
        assert "Track A1" not in titles_b
        assert "Track A2" not in titles_b


class TestAudioTrackDetailsAndStatus:
    async def test_get_track_details_and_status(
        self, async_client: AsyncClient, user_a_tokens, user_b_tokens
    ):
        # User A uploads track
        mp3_bytes = create_mock_mp3_bytes()
        upload_res = await async_client.post(
            "/api/v1/audio/upload",
            headers=user_a_tokens["headers"],
            data={"title": "Status Test Track"},
            files={"file": ("status.mp3", mp3_bytes, "audio/mpeg")},
        )
        assert upload_res.status_code == 201
        track_id = upload_res.json()["data"]["id"]
        job_id = upload_res.json()["data"]["processing_jobs"][0]["id"]

        # User A retrieves track details
        detail_res = await async_client.get(
            f"/api/v1/audio/tracks/{track_id}",
            headers=user_a_tokens["headers"],
        )
        assert detail_res.status_code == 200
        assert detail_res.json()["data"]["id"] == track_id

        # User A retrieves track status
        status_res = await async_client.get(
            f"/api/v1/audio/tracks/{track_id}/status",
            headers=user_a_tokens["headers"],
        )
        assert status_res.status_code == 200
        status_data = status_res.json()["data"]
        assert status_data["track_id"] == track_id
        assert status_data["status"] == "UPLOADED"
        assert status_data["processing_status"] == "PENDING"
        assert status_data["processing_job_id"] == job_id

        # User A retrieves job details
        job_res = await async_client.get(
            f"/api/v1/audio/jobs/{job_id}",
            headers=user_a_tokens["headers"],
        )
        assert job_res.status_code == 200
        assert job_res.json()["data"]["id"] == job_id
        assert job_res.json()["data"]["status"] == "PENDING"

        # User B attempts to access User A's track -> 404 NOT_FOUND
        forbidden_track = await async_client.get(
            f"/api/v1/audio/tracks/{track_id}",
            headers=user_b_tokens["headers"],
        )
        assert forbidden_track.status_code == 404

        # User B attempts to access User A's job -> 404 NOT_FOUND
        forbidden_job = await async_client.get(
            f"/api/v1/audio/jobs/{job_id}",
            headers=user_b_tokens["headers"],
        )
        assert forbidden_job.status_code == 404

    async def test_get_nonexistent_track_returns_404(
        self, async_client: AsyncClient, user_a_tokens
    ):
        random_id = uuid.uuid4()
        res = await async_client.get(
            f"/api/v1/audio/tracks/{random_id}",
            headers=user_a_tokens["headers"],
        )
        assert res.status_code == 404
        assert res.json()["success"] is False
