import hashlib
import json
import logging
import uuid

import redis.asyncio as aioredis

from app.core.config import get_settings
from app.repositories.search_repository import SearchRepository
from app.schemas.search import (
    SearchAlbumItem,
    SearchArtistItem,
    SearchPlaylistItem,
    SearchResponse,
    SearchSuggestionsResponse,
    SearchTrackItem,
    SearchType,
)
from app.utils.storage import BaseStorageService

logger = logging.getLogger("hums.search_service")
settings = get_settings()


class SearchService:
    """Service orchestrating cross-entity search, relevance delivery, and autocomplete caching."""

    def __init__(
        self,
        search_repository: SearchRepository,
        storage_service: BaseStorageService,
    ):
        self.search_repo = search_repository
        self.storage_service = storage_service

    async def search(
        self,
        query: str,
        search_type: SearchType = SearchType.ALL,
        limit: int = 20,
        skip: int = 0,
        current_user_id: uuid.UUID | None = None,
    ) -> SearchResponse:
        """
        Executes unified or entity-filtered catalog search.
        Handles query trimming, bounds checking, and visibility rules across:
        tracks, artists, albums, playlists, podcasts, episodes.
        """
        clean_q = query.strip()
        limit = max(1, min(limit, 50))
        skip = max(0, skip)

        if not clean_q or len(clean_q) < 1:
            return SearchResponse(
                query=clean_q,
                type=search_type.value,
                total_tracks=0,
                total_artists=0,
                total_albums=0,
                total_playlists=0,
                total_podcasts=0,
                total_episodes=0,
                tracks=[],
                artists=[],
                albums=[],
                playlists=[],
                podcasts=[],
                episodes=[],
            )

        track_items = []
        total_tracks = 0
        artist_items = []
        total_artists = 0
        album_items = []
        total_albums = 0
        playlist_items = []
        total_playlists = 0
        podcast_items = []
        total_podcasts = 0
        episode_items = []
        total_episodes = 0

        # Tracks
        if search_type in (SearchType.ALL, SearchType.TRACKS):
            tracks, total_tracks = await self.search_repo.search_tracks(
                query_str=clean_q,
                limit=limit,
                skip=skip if search_type == SearchType.TRACKS else 0,
            )
            track_items = [SearchTrackItem.model_validate(t) for t in tracks]

        # Artists
        if search_type in (SearchType.ALL, SearchType.ARTISTS):
            artists, total_artists = await self.search_repo.search_artists(
                query_str=clean_q,
                limit=limit,
                skip=skip if search_type == SearchType.ARTISTS else 0,
            )
            artist_items = [SearchArtistItem.model_validate(a) for a in artists]

        # Albums
        if search_type in (SearchType.ALL, SearchType.ALBUMS):
            albums, total_albums = await self.search_repo.search_albums(
                query_str=clean_q,
                limit=limit,
                skip=skip if search_type == SearchType.ALBUMS else 0,
            )
            album_items = [SearchAlbumItem.model_validate(a) for a in albums]

        # Playlists
        if search_type in (SearchType.ALL, SearchType.PLAYLISTS):
            playlists_with_count, total_playlists = await self.search_repo.search_playlists(
                query_str=clean_q,
                current_user_id=current_user_id,
                limit=limit,
                skip=skip if search_type == SearchType.PLAYLISTS else 0,
            )
            for p, count in playlists_with_count:
                cover_url = None
                if p.cover_image_key:
                    cover_url = await self.storage_service.get_download_url(p.cover_image_key)
                playlist_items.append(
                    SearchPlaylistItem(
                        id=p.id,
                        owner_id=p.owner_id,
                        name=p.name,
                        description=p.description,
                        cover_image_key=p.cover_image_key,
                        cover_image_url=cover_url,
                        is_public=p.is_public,
                        track_count=count,
                        created_at=p.created_at,
                        updated_at=p.updated_at,
                    )
                )

        # Podcasts & Episodes (Ready for future schema extensions)
        if search_type == SearchType.PODCASTS:
            podcast_items = []
            total_podcasts = 0

        if search_type == SearchType.EPISODES:
            episode_items = []
            total_episodes = 0

        return SearchResponse(
            query=clean_q,
            type=search_type.value,
            total_tracks=total_tracks,
            total_artists=total_artists,
            total_albums=total_albums,
            total_playlists=total_playlists,
            total_podcasts=total_podcasts,
            total_episodes=total_episodes,
            tracks=track_items,
            artists=artist_items,
            albums=album_items,
            playlists=playlist_items,
            podcasts=podcast_items,
            episodes=episode_items,
        )

    async def get_suggestions(
        self,
        query: str,
        limit: int = 8,
        current_user_id: uuid.UUID | None = None,
    ) -> SearchSuggestionsResponse:
        """
        Retrieves fast autocomplete suggestions with Redis caching.
        Deduplicates suggestions across titles, artists, albums, and playlists.
        """
        clean_q = query.strip()
        limit = max(1, min(limit, 20))
        if not clean_q:
            return SearchSuggestionsResponse(query=clean_q, suggestions=[])

        cache_key = None
        # Only cache unauthenticated / public query suggestions globally
        if current_user_id is None:
            q_hash = hashlib.sha256(clean_q.lower().encode("utf-8")).hexdigest()[:16]
            cache_key = f"search:suggestions:{q_hash}:{limit}"
            try:
                client = aioredis.from_url(
                    settings.REDIS_URL,
                    encoding="utf-8",
                    decode_responses=True,
                    socket_connect_timeout=0.5,
                    socket_timeout=0.5,
                )
                async with client:
                    cached_val = await client.get(cache_key)
                    if cached_val:
                        suggestions = json.loads(cached_val)
                        return SearchSuggestionsResponse(query=clean_q, suggestions=suggestions)
            except Exception as exc:  # noqa: BLE001
                logger.debug(f"Redis suggestion cache miss / error: {exc}")

        suggestions = await self.search_repo.get_suggestions(
            query_str=clean_q,
            limit=limit,
            current_user_id=current_user_id,
        )

        if cache_key:
            try:
                client = aioredis.from_url(
                    settings.REDIS_URL,
                    encoding="utf-8",
                    decode_responses=True,
                    socket_connect_timeout=0.5,
                    socket_timeout=0.5,
                )
                async with client:
                    await client.set(cache_key, json.dumps(suggestions), ex=60)
            except Exception as exc:  # noqa: BLE001
                logger.debug(f"Failed to cache suggestions in Redis: {exc}")

        return SearchSuggestionsResponse(query=clean_q, suggestions=suggestions)
