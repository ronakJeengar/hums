import logging
import uuid
from typing import Optional
from app.repositories.search_repository import SearchRepository
from app.schemas.search import (
    SearchArtistItem,
    SearchPlaylistItem,
    SearchResponse,
    SearchTrackItem,
    SearchType,
)
from app.utils.storage import BaseStorageService

logger = logging.getLogger("hums.search_service")


class SearchService:
    """Service orchestrating cross-entity search and relevance delivery."""

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
        current_user_id: Optional[uuid.UUID] = None,
    ) -> SearchResponse:
        """
        Executes unified or entity-filtered catalog search.
        Handles query trimming, bounds checking, and visibility rules.
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
                total_playlists=0,
                tracks=[],
                artists=[],
                playlists=[],
            )

        track_items = []
        total_tracks = 0
        artist_items = []
        total_artists = 0
        playlist_items = []
        total_playlists = 0

        # In "all" mode, search all three categories up to limit
        if search_type in (SearchType.ALL, SearchType.TRACKS):
            tracks, total_tracks = await self.search_repo.search_tracks(
                query_str=clean_q,
                limit=limit,
                skip=skip if search_type == SearchType.TRACKS else 0,
            )
            track_items = [SearchTrackItem.model_validate(t) for t in tracks]

        if search_type in (SearchType.ALL, SearchType.ARTISTS):
            artists, total_artists = await self.search_repo.search_artists(
                query_str=clean_q,
                limit=limit,
                skip=skip if search_type == SearchType.ARTISTS else 0,
            )
            artist_items = [SearchArtistItem.model_validate(a) for a in artists]

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

        return SearchResponse(
            query=clean_q,
            type=search_type.value,
            total_tracks=total_tracks,
            total_artists=total_artists,
            total_playlists=total_playlists,
            tracks=track_items,
            artists=artist_items,
            playlists=playlist_items,
        )
