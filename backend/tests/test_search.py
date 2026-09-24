import uuid
import pytest
from httpx import AsyncClient

from app.db.database import AsyncSessionLocal
from app.db.models.audio import Track
from app.db.models.playlist import Playlist
from app.db.models.user import User
from app.repositories.audio_repository import TrackRepository
from app.repositories.playlist_repository import PlaylistRepository


@pytest.fixture
async def search_user1(async_client: AsyncClient):
    """Creates authenticated User 1."""
    email = f"search_user1_{uuid.uuid4().hex[:8]}@example.com"
    password = "SecurePassword123!"
    res = await async_client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": password, "name": "Kabir Sharma"},
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
async def search_user2(async_client: AsyncClient):
    """Creates authenticated User 2."""
    email = f"search_user2_{uuid.uuid4().hex[:8]}@example.com"
    password = "SecurePassword123!"
    res = await async_client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": password, "name": "Meera Patel"},
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


@pytest.mark.asyncio
class TestSearchApi:
    """Test suite for backend search API endpoint /api/v1/search."""

    async def test_empty_or_whitespace_query_returns_empty_results(self, async_client: AsyncClient):
        """Querying with empty or whitespace-only string gracefully returns empty results."""
        res = await async_client.get("/api/v1/search?q=")
        assert res.status_code == 200
        body = res.json()
        assert body["success"] is True
        data = body["data"]
        assert data["query"] == ""
        assert data["total_tracks"] == 0
        assert data["total_artists"] == 0
        assert data["total_playlists"] == 0
        assert data["tracks"] == []
        assert data["artists"] == []
        assert data["playlists"] == []

        res_ws = await async_client.get("/api/v1/search?q=     ")
        assert res_ws.status_code == 200
        assert res_ws.json()["data"]["total_tracks"] == 0

    async def test_search_tracks_exact_and_prefix(self, async_client: AsyncClient, search_user1):
        """Tests exact and prefix matching with relevance order on tracks."""
        async with AsyncSessionLocal() as session:
            track_repo = TrackRepository(session)
            t1 = await track_repo.create(
                id=uuid.uuid4(),
                owner_id=search_user1["id"],
                title="Kesariya Tera Ishq Hai Piya",
                artist_name="Arijit Singh",
                album_name="Brahmastra",
                genre="Romantic",
                status="READY",
            )
            t2 = await track_repo.create(
                id=uuid.uuid4(),
                owner_id=search_user1["id"],
                title="Apna Bana Le",
                artist_name="Arijit Singh",
                album_name="Bhediya",
                genre="Romantic",
                status="READY",
            )
            await session.commit()

        # Query exact title prefix
        res = await async_client.get("/api/v1/search?q=Kesariya&type=tracks")
        assert res.status_code == 200
        data = res.json()["data"]
        assert data["total_tracks"] >= 1
        assert any(t["id"] == str(t1.id) for t in data["tracks"])
        assert data["tracks"][0]["title"] == "Kesariya Tera Ishq Hai Piya"

        # Query artist name across tracks
        res_artist = await async_client.get("/api/v1/search?q=Arijit&type=tracks")
        assert res_artist.status_code == 200
        data_artist = res_artist.json()["data"]
        track_ids = [t["id"] for t in data_artist["tracks"]]
        assert str(t1.id) in track_ids
        assert str(t2.id) in track_ids

    async def test_case_insensitivity_and_partial_substring(self, async_client: AsyncClient, search_user1):
        """Search is case-insensitive and matches mid-string substrings."""
        async with AsyncSessionLocal() as session:
            track_repo = TrackRepository(session)
            t = await track_repo.create(
                id=uuid.uuid4(),
                owner_id=search_user1["id"],
                title="Sublime Morning Waves",
                artist_name="Ocean Echoes",
                album_name="Ambient Horizons",
                genre="Ambient",
                status="READY",
            )
            await session.commit()

        for term in ["sublime", "SUBLIME", "Morning", "WAVES", "Echoes"]:
            res = await async_client.get(f"/api/v1/search?q={term}&type=tracks")
            assert res.status_code == 200
            data = res.json()["data"]
            assert any(track["id"] == str(t.id) for track in data["tracks"])

    async def test_unready_tracks_are_strictly_excluded(self, async_client: AsyncClient, search_user1):
        """Tracks with status != READY (e.g. UPLOADED, PROCESSING, FAILED) must never appear in search."""
        async with AsyncSessionLocal() as session:
            track_repo = TrackRepository(session)
            t_unready = await track_repo.create(
                id=uuid.uuid4(),
                owner_id=search_user1["id"],
                title="TopSecretUnpublishedDemo999",
                artist_name="Stealth Artist",
                status="PROCESSING",
            )
            await session.commit()

        res = await async_client.get("/api/v1/search?q=TopSecretUnpublishedDemo999")
        assert res.status_code == 200
        data = res.json()["data"]
        assert all(t["id"] != str(t_unready.id) for t in data["tracks"])
        assert data["total_tracks"] == 0

    async def test_playlist_visibility_isolation(self, async_client: AsyncClient, search_user1, search_user2):
        """
        Public playlists are visible to all users (even guest/unauthenticated).
        Private playlists are only visible to their creator.
        """
        unique_term = f"IsolationTest_{uuid.uuid4().hex[:6]}"
        async with AsyncSessionLocal() as session:
            playlist_repo = PlaylistRepository(session)
            # User 1 Public Playlist
            p_public = await playlist_repo.create(
                id=uuid.uuid4(),
                owner_id=search_user1["id"],
                name=f"{unique_term} Public Grooves",
                is_public=True,
            )
            # User 1 Private Playlist
            p1_private = await playlist_repo.create(
                id=uuid.uuid4(),
                owner_id=search_user1["id"],
                name=f"{unique_term} User1 Secret Lounge",
                is_public=False,
            )
            # User 2 Private Playlist
            p2_private = await playlist_repo.create(
                id=uuid.uuid4(),
                owner_id=search_user2["id"],
                name=f"{unique_term} User2 Diary Hidden",
                is_public=False,
            )
            await session.commit()

        # 1. Unauthenticated guest search: sees only public playlist
        res_guest = await async_client.get(f"/api/v1/search?q={unique_term}&type=playlists")
        assert res_guest.status_code == 200
        guest_ids = [p["id"] for p in res_guest.json()["data"]["playlists"]]
        assert str(p_public.id) in guest_ids
        assert str(p1_private.id) not in guest_ids
        assert str(p2_private.id) not in guest_ids

        # 2. User 1 search: sees public playlist AND their own private playlist, but NOT User 2's private playlist
        res_u1 = await async_client.get(
            f"/api/v1/search?q={unique_term}&type=playlists",
            headers=search_user1["headers"],
        )
        assert res_u1.status_code == 200
        u1_ids = [p["id"] for p in res_u1.json()["data"]["playlists"]]
        assert str(p_public.id) in u1_ids
        assert str(p1_private.id) in u1_ids
        assert str(p2_private.id) not in u1_ids

        # 3. User 2 search: sees public playlist AND their own private playlist, but NOT User 1's private playlist
        res_u2 = await async_client.get(
            f"/api/v1/search?q={unique_term}&type=playlists",
            headers=search_user2["headers"],
        )
        assert res_u2.status_code == 200
        u2_ids = [p["id"] for p in res_u2.json()["data"]["playlists"]]
        assert str(p_public.id) in u2_ids
        assert str(p1_private.id) not in u2_ids
        assert str(p2_private.id) in u2_ids

    async def test_artist_search_from_users_and_metadata(self, async_client: AsyncClient, search_user1):
        """Artists can be registered creators or artists indicated in track metadata."""
        artist_name = f"Maestro_{uuid.uuid4().hex[:6]}"
        async with AsyncSessionLocal() as session:
            track_repo = TrackRepository(session)
            await track_repo.create(
                id=uuid.uuid4(),
                owner_id=search_user1["id"],
                title="Symphony in C Minor",
                artist_name=artist_name,
                status="READY",
            )
            await session.commit()

        # Search for creator User 1 by name
        res_user = await async_client.get("/api/v1/search?q=Kabir&type=artists")
        assert res_user.status_code == 200
        user_artists = res_user.json()["data"]["artists"]
        assert any("Kabir" in a["name"] for a in user_artists)

        # Search for track metadata artist
        res_meta = await async_client.get(f"/api/v1/search?q={artist_name}&type=artists")
        assert res_meta.status_code == 200
        meta_artists = res_meta.json()["data"]["artists"]
        assert any(a["name"] == artist_name for a in meta_artists)
        matched_artist = next(a for a in meta_artists if a["name"] == artist_name)
        assert matched_artist["track_count"] >= 1

    async def test_search_type_filtering(self, async_client: AsyncClient, search_user1):
        """Testing type=tracks, type=artists, type=playlists filtering behavior."""
        term = f"TypeFilter_{uuid.uuid4().hex[:6]}"
        async with AsyncSessionLocal() as session:
            track_repo = TrackRepository(session)
            playlist_repo = PlaylistRepository(session)
            await track_repo.create(
                id=uuid.uuid4(),
                owner_id=search_user1["id"],
                title=f"{term} Audio Anthem",
                status="READY",
            )
            await playlist_repo.create(
                id=uuid.uuid4(),
                owner_id=search_user1["id"],
                name=f"{term} Playlist Collection",
                is_public=True,
            )
            await session.commit()

        # type=tracks: only tracks populated
        res_t = await async_client.get(f"/api/v1/search?q={term}&type=tracks")
        assert res_t.status_code == 200
        data_t = res_t.json()["data"]
        assert data_t["total_tracks"] >= 1
        assert data_t["total_playlists"] == 0
        assert data_t["total_artists"] == 0
        assert len(data_t["tracks"]) >= 1
        assert len(data_t["playlists"]) == 0
        assert len(data_t["artists"]) == 0

        # type=playlists: only playlists populated
        res_p = await async_client.get(f"/api/v1/search?q={term}&type=playlists")
        assert res_p.status_code == 200
        data_p = res_p.json()["data"]
        assert data_p["total_playlists"] >= 1
        assert data_p["total_tracks"] == 0
        assert data_p["total_artists"] == 0
        assert len(data_p["playlists"]) >= 1
        assert len(data_p["tracks"]) == 0

    async def test_pagination_limit_and_skip(self, async_client: AsyncClient, search_user1):
        """Pagination limit and skip works properly for filtered search."""
        prefix = f"Paging_{uuid.uuid4().hex}"
        async with AsyncSessionLocal() as session:
            track_repo = TrackRepository(session)
            for i in range(5):
                await track_repo.create(
                    id=uuid.uuid4(),
                    owner_id=search_user1["id"],
                    title=f"{prefix} Track Number {i}",
                    status="READY",
                )
            await session.commit()

        # Page 1: limit 2, skip 0
        res1 = await async_client.get(f"/api/v1/search?q={prefix}&type=tracks&limit=2&skip=0")
        assert res1.status_code == 200
        data1 = res1.json()["data"]
        assert data1["total_tracks"] == 5
        assert len(data1["tracks"]) == 2

        # Page 2: limit 2, skip 2
        res2 = await async_client.get(f"/api/v1/search?q={prefix}&type=tracks&limit=2&skip=2")
        assert res2.status_code == 200
        data2 = res2.json()["data"]
        assert data2["total_tracks"] == 5
        assert len(data2["tracks"]) == 2

        # Ensure disjoint items across pages
        ids1 = {t["id"] for t in data1["tracks"]}
        ids2 = {t["id"] for t in data2["tracks"]}
        assert ids1.isdisjoint(ids2)

    async def test_special_characters_and_sql_injection_resilience(self, async_client: AsyncClient):
        """Malicious SQL strings and special characters are safely escaped without throwing 500."""
        malicious_inputs = [
            "' OR '1'='1",
            "'; DROP TABLE tracks; --",
            "' UNION SELECT * FROM users --",
            "%",
            "_",
            "\\",
            "/?$#@!*&^()~`",
        ]
        for query in malicious_inputs:
            res = await async_client.get("/api/v1/search", params={"q": query})
            assert res.status_code == 200
            assert res.json()["success"] is True

    async def test_multilingual_unicode_search(self, async_client: AsyncClient, search_user1):
        """Multilingual UTF-8 queries (e.g. Hindi, Sanskrit, Hinglish) return matching content."""
        hindi_title = "दिल का दरिया बह ही गया"
        async with AsyncSessionLocal() as session:
            track_repo = TrackRepository(session)
            t = await track_repo.create(
                id=uuid.uuid4(),
                owner_id=search_user1["id"],
                title=hindi_title,
                artist_name="अरिजीत सिंह",
                genre="सूफी",
                status="READY",
            )
            await session.commit()

        res = await async_client.get("/api/v1/search?q=दरिया&type=tracks")
        assert res.status_code == 200
        tracks = res.json()["data"]["tracks"]
        assert any(track["id"] == str(t.id) for track in tracks)
