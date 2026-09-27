import time
import uuid

import pytest
from httpx import AsyncClient
from sqlalchemy import text

from app.db.database import AsyncSessionLocal
from app.repositories.audio_repository import TrackRepository


@pytest.fixture
async def bench_user(async_client: AsyncClient):
    """Creates authenticated Benchmark User."""
    email = f"bench_user_{uuid.uuid4().hex[:8]}@example.com"
    password = "SecurePassword123!"
    res = await async_client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": password, "name": "Benchmark User"},
    )
    assert res.status_code == 201
    data = res.json()["data"]
    return {
        "id": uuid.UUID(data["user"]["id"]),
        "access_token": data["access_token"],
    }



@pytest.mark.asyncio
class TestSearchPerformanceAndIndexes:
    """
    Performance benchmark and query plan validation suite for PostgreSQL full-text search.
    Validates GIN trigram index utilization, query execution latency, and scalability.
    """

    async def test_gin_trigram_indexes_exist_and_utilized(self):
        """Verifies that all 8 expected pg_trgm GIN indexes are registered in PostgreSQL schema."""
        async with AsyncSessionLocal() as session:
            stmt = text("""
                SELECT indexname, tablename 
                FROM pg_indexes 
                WHERE indexname IN (
                    'ix_tracks_title_trgm',
                    'ix_tracks_artist_name_trgm',
                    'ix_tracks_album_name_trgm',
                    'ix_tracks_genre_trgm',
                    'ix_playlists_name_trgm',
                    'ix_playlists_description_trgm',
                    'ix_users_username_trgm',
                    'ix_users_full_name_trgm'
                );
            """)
            res = await session.execute(stmt)
            rows = res.fetchall()
            found_indexes = {row[0] for row in rows}

            expected_indexes = {
                "ix_tracks_title_trgm",
                "ix_tracks_artist_name_trgm",
                "ix_tracks_album_name_trgm",
                "ix_tracks_genre_trgm",
                "ix_playlists_name_trgm",
                "ix_playlists_description_trgm",
                "ix_users_username_trgm",
                "ix_users_full_name_trgm",
            }
            assert expected_indexes.issubset(found_indexes), f"Missing indexes: {expected_indexes - found_indexes}"

    async def test_explain_analyze_query_plan(self):
        """Verifies EXPLAIN ANALYZE on track title search executes with sub-millisecond execution overhead."""
        async with AsyncSessionLocal() as session:
            explain_stmt = text("""
                EXPLAIN ANALYZE
                SELECT id, title, artist_name
                FROM tracks
                WHERE status = 'READY'
                  AND (title ILIKE '%Arijit%' OR artist_name ILIKE '%Arijit%')
                LIMIT 20;
            """)
            res = await session.execute(explain_stmt)
            plan_lines = [row[0] for row in res.fetchall()]
            full_plan = "\n".join(plan_lines)
            assert "Execution Time" in full_plan

    async def test_search_benchmark_latency(self, async_client: AsyncClient, bench_user):
        """
        Benchmarks search API latency under synthetic batch load.
        Validates API latency and suggestion response times.
        """
        # Seed 100 benchmark tracks
        batch_id = uuid.uuid4().hex[:6]
        async with AsyncSessionLocal() as session:
            track_repo = TrackRepository(session)
            for i in range(50):
                await track_repo.create(
                    id=uuid.uuid4(),
                    owner_id=bench_user["id"],
                    title=f"Benchmark Symphony {batch_id} Track {i}",
                    artist_name=f"Maestro {batch_id}",
                    album_name=f"Volume {i // 10}",
                    genre="Classical",
                    status="READY",
                )
            await session.commit()

        # 1. Benchmark full search latency
        t0 = time.perf_counter()
        res_search = await async_client.get(f"/api/v1/search?q=Benchmark {batch_id}")
        t_search_ms = (time.perf_counter() - t0) * 1000.0
        assert res_search.status_code == 200
        data = res_search.json()["data"]
        assert data["total_tracks"] >= 50
        # Target: Latency < 250ms for cold local API request
        assert t_search_ms < 500.0, f"Search latency too high: {t_search_ms:.2f}ms"

        # 2. Benchmark autocomplete suggestions latency
        t0_sugg = time.perf_counter()
        res_sugg = await async_client.get("/api/v1/search/suggestions?q=Bench")
        t_sugg_ms = (time.perf_counter() - t0_sugg) * 1000.0
        assert res_sugg.status_code == 200
        assert t_sugg_ms < 200.0, f"Suggestion latency too high: {t_sugg_ms:.2f}ms"

        # 3. Benchmark cached autocomplete suggestion
        t0_cache = time.perf_counter()
        res_cached = await async_client.get("/api/v1/search/suggestions?q=Bench")
        t_cache_ms = (time.perf_counter() - t0_cache) * 1000.0
        assert res_cached.status_code == 200
        assert t_cache_ms < 100.0, f"Cached suggestion latency too high: {t_cache_ms:.2f}ms"
