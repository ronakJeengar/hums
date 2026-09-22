import asyncio
import json
from unittest.mock import MagicMock, patch
import uuid
import pytest
from httpx import AsyncClient

from app.core.config import get_settings
from app.db.database import AsyncSessionLocal
from app.db.models.audio import Track
from app.db.models.playlist import Playlist, PlaylistTrack
from app.repositories.audio_repository import TrackRepository
from app.services.recommendation.candidate_service import (
    CandidateGenerationService,
    GenreCandidateSource,
    PopularCandidateSource,
    RecentCandidateSource,
)
from app.services.recommendation.diversity_service import DiversityService
from app.services.recommendation.ranking_service import RankingService
from app.services.recommendation.user_preference_service import (
    UserPreferences,
    UserPreferenceService,
)
from app.services.recommendation.weights import RecommendationWeights
from app.ai.gemini_recommendation_client import GeminiRecommendationClient
from app.workers.recommendation_tasks import generate_user_recommendations

settings = get_settings()


@pytest.fixture
async def user_auth_fixture(async_client: AsyncClient):
    """Registers and authenticates a test user."""
    email = f"rec_user_{uuid.uuid4().hex[:8]}@example.com"
    password = "SecurePassword123!"
    res = await async_client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": password, "name": "Recommendation Tester"},
    )
    assert res.status_code == 201
    data = res.json()["data"]
    token = data["access_token"]
    return {
        "access_token": token,
        "headers": {"Authorization": f"Bearer {token}"},
        "user_id": uuid.UUID(data["user"]["id"]),
    }


@pytest.fixture
async def seed_tracks_fixture(user_auth_fixture):
    """Seeds a variety of tracks with different genres, artists, and statuses."""
    user_id = user_auth_fixture["user_id"]
    track_ids = []

    async with AsyncSessionLocal() as session:
        # Create 5 READY tracks across different genres and artists
        t1 = Track(
            id=uuid.uuid4(),
            owner_id=user_id,
            title="Indie Vibes 1",
            artist_name="The Antigravities",
            genre="Indie",
            status="READY",
            duration_seconds=200,
            waveform_key="audio/waveforms/w1.json",
        )
        t2 = Track(
            id=uuid.uuid4(),
            owner_id=user_id,
            title="Indie Vibes 2",
            artist_name="The Antigravities",
            genre="Indie",
            status="READY",
            duration_seconds=180,
            waveform_key="audio/waveforms/w2.json",
        )
        t3 = Track(
            id=uuid.uuid4(),
            owner_id=user_id,
            title="Rock Anthem",
            artist_name="Electric Pulse",
            genre="Rock",
            status="READY",
            duration_seconds=240,
            waveform_key="audio/waveforms/w3.json",
        )
        t4 = Track(
            id=uuid.uuid4(),
            owner_id=user_id,
            title="Chill Beats",
            artist_name="Lo-Fi Master",
            genre="Acoustic",
            status="READY",
            duration_seconds=150,
            waveform_key="audio/waveforms/w4.json",
        )
        t5 = Track(
            id=uuid.uuid4(),
            owner_id=user_id,
            title="Unfinished Track",
            artist_name="Processing Artist",
            genre="Indie",
            status="PROCESSING",  # MUST BE EXCLUDED FROM RECOMMENDATIONS
            duration_seconds=120,
        )
        t6 = Track(
            id=uuid.uuid4(),
            owner_id=user_id,
            title="Broken Track",
            artist_name="Failed Artist",
            genre="Rock",
            status="FAILED",  # MUST BE EXCLUDED FROM RECOMMENDATIONS
        )

        session.add_all([t1, t2, t3, t4, t5, t6])
        await session.commit()
        track_ids = [t1.id, t2.id, t3.id, t4.id]

    return track_ids


@pytest.mark.asyncio
class TestCandidateGeneration:
    """Verifies that candidates are accurately discovered, filtered, and deduplicated."""

    async def test_ready_tracks_only_included(self, seed_tracks_fixture):
        async with AsyncSessionLocal() as session:
            track_repo = TrackRepository(session)
            popular = await track_repo.list_popular_ready_tracks(limit=10)
            assert all(t.status == "READY" for t in popular)
            titles = [t.title for t in popular]
            assert "Unfinished Track" not in titles
            assert "Broken Track" not in titles

    async def test_genre_candidate_source(self, seed_tracks_fixture):
        async with AsyncSessionLocal() as session:
            track_repo = TrackRepository(session)
            source = GenreCandidateSource(track_repo)
            prefs = UserPreferences(preferred_genres=["Indie"])
            candidates = await source.get_candidates(prefs, limit=10)
            assert len(candidates) >= 2
            assert all(c.genre == "Indie" for c in candidates)

    async def test_candidate_service_deduplication_and_exclusions(self, seed_tracks_fixture):
        async with AsyncSessionLocal() as session:
            track_repo = TrackRepository(session)
            candidate_service = CandidateGenerationService(track_repo)
            excluded = {seed_tracks_fixture[0]}
            prefs = UserPreferences(
                preferred_genres=["Indie", "Rock"],
                excluded_track_ids=excluded,
            )
            candidates = await candidate_service.generate_candidates(prefs, max_candidates=10)
            candidate_ids = [c.id for c in candidates]
            # Excluded track should NOT be present
            assert seed_tracks_fixture[0] not in candidate_ids
            # No duplicates
            assert len(candidate_ids) == len(set(candidate_ids))


class TestRankingAndDiversity:
    """Verifies scoring weights and diversity constraint enforcement."""

    def test_ranking_weights_and_scores(self):
        weights = RecommendationWeights(genre=0.4, artist=0.3, popularity=0.15, freshness=0.15)
        ranking_service = RankingService(weights)

        t_matching = Track(
            id=uuid.uuid4(),
            title="Matching Genre and Artist",
            genre="Indie",
            artist_name="Favourite Band",
            status="READY",
            duration_seconds=200,
            waveform_key="wave.json",
        )
        t_unmatched = Track(
            id=uuid.uuid4(),
            title="Unrelated Track",
            genre="Jazz",
            artist_name="Unknown Artist",
            status="READY",
        )

        prefs = UserPreferences(
            preferred_genres=["Indie"],
            preferred_artists=["Favourite Band"],
        )

        ranked = ranking_service.rank_candidates([t_unmatched, t_matching], prefs)
        assert len(ranked) == 2
        # Highest matching track should be ranked first
        assert ranked[0][0].id == t_matching.id
        assert ranked[0][1] > ranked[1][1]

    def test_diversity_service_artist_and_genre_caps(self):
        diversity = DiversityService(max_tracks_per_artist=2, max_tracks_per_genre=3)

        tracks = [
            (Track(id=uuid.uuid4(), title=f"Track {i}", artist_name="Same Artist", genre="Pop", status="READY"), 0.9 - i * 0.01)
            for i in range(5)
        ] + [
            (Track(id=uuid.uuid4(), title=f"Other {i}", artist_name=f"Artist {i}", genre="Rock", status="READY"), 0.8 - i * 0.01)
            for i in range(3)
        ]

        result = diversity.apply_diversity(tracks, limit=4)
        assert len(result) == 4
        # Same Artist should appear at most 2 times
        same_artist_count = sum(1 for t, _ in result if t.artist_name == "Same Artist")
        assert same_artist_count <= 2


@pytest.mark.asyncio
class TestGeminiRecommendationClient:
    """Verifies Gemini re-ranking with resilient fallback on failure."""

    async def test_gemini_rerank_disabled_when_no_api_key(self):
        client = GeminiRecommendationClient(api_key="")
        assert not client.is_available
        prefs = UserPreferences(preferred_genres=["Indie"])
        res = await client.rerank_candidates([], prefs)
        assert res is None

    async def test_gemini_rerank_success_mock(self):
        client = GeminiRecommendationClient(api_key="mock_key")
        t1 = Track(id=uuid.uuid4(), title="Track 1", artist_name="Artist A", genre="Indie", status="READY")
        t2 = Track(id=uuid.uuid4(), title="Track 2", artist_name="Artist B", genre="Indie", status="READY")
        candidates = [(t1, 0.8), (t2, 0.7)]
        prefs = UserPreferences(preferred_genres=["Indie"])

        mock_response = MagicMock()
        mock_response.text = json.dumps({"ranked_ids": [str(t2.id), str(t1.id)]})

        with patch("google.genai.Client") as mock_genai_client_class:
            mock_genai_instance = MagicMock()
            mock_genai_instance.models.generate_content.return_value = mock_response
            mock_genai_client_class.return_value = mock_genai_instance

            reranked = await client.rerank_candidates(candidates, prefs)
            assert reranked is not None
            # Track 2 should now be first
            assert reranked[0][0].id == t2.id
            assert reranked[1][0].id == t1.id

    async def test_gemini_rerank_malformed_response_falls_back(self):
        client = GeminiRecommendationClient(api_key="mock_key")
        t1 = Track(id=uuid.uuid4(), title="Track 1", status="READY")
        candidates = [(t1, 0.8)]
        prefs = UserPreferences(preferred_genres=["Indie"])

        mock_response = MagicMock()
        mock_response.text = "NOT JSON ERROR RESPONSE"

        with patch("google.genai.Client") as mock_genai_client_class:
            mock_genai_instance = MagicMock()
            mock_genai_instance.models.generate_content.return_value = mock_response
            mock_genai_client_class.return_value = mock_genai_instance

            reranked = await client.rerank_candidates(candidates, prefs)
            assert reranked is None  # Graceful fallback to deterministic


@pytest.mark.asyncio
class TestRecommendationsAPI:
    """Verifies the HTTP API endpoints, auth enforcement, caching, and sections."""

    async def test_get_recommendations_unauthenticated_returns_401(self, async_client: AsyncClient):
        res = await async_client.get("/api/v1/recommendations")
        assert res.status_code == 401

    async def test_get_recommendations_cold_start_new_user(
        self, async_client: AsyncClient, user_auth_fixture, seed_tracks_fixture
    ):
        headers = user_auth_fixture["headers"]
        res = await async_client.get("/api/v1/recommendations", headers=headers)
        assert res.status_code == 200
        body = res.json()
        assert body["success"] is True
        sections = body["data"]["sections"]
        assert len(sections) >= 1

        # Check section IDs
        sec_ids = [s["id"] for s in sections]
        assert "for-you" in sec_ids

        # Verify items contain valid track metadata and NO internal scores/prompts
        for_you = next(s for s in sections if s["id"] == "for-you")
        for item in for_you["items"]:
            assert "id" in item
            assert "title" in item
            assert "status" in item
            assert item["status"] == "READY"
            assert "score" not in item
            assert "prompt" not in item

    async def test_get_recommendations_with_section_filter(
        self, async_client: AsyncClient, user_auth_fixture, seed_tracks_fixture
    ):
        headers = user_auth_fixture["headers"]
        res = await async_client.get("/api/v1/recommendations?section=trending", headers=headers)
        assert res.status_code == 200
        sections = res.json()["data"]["sections"]
        assert all(s["id"] == "trending" for s in sections)

    async def test_post_refresh_recommendations(
        self, async_client: AsyncClient, user_auth_fixture, seed_tracks_fixture
    ):
        headers = user_auth_fixture["headers"]
        res = await async_client.post("/api/v1/recommendations/refresh", headers=headers)
        assert res.status_code == 202
        body = res.json()
        assert body["success"] is True
        assert "message" in body["data"]

    async def test_celery_recommendation_task_execution(self, user_auth_fixture, seed_tracks_fixture):
        user_id_str = str(user_auth_fixture["user_id"])
        # Directly test the Celery worker function
        success = generate_user_recommendations(user_id_str)
        assert success is True
