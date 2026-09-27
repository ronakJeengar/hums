import uuid
from typing import List, Optional
from sqlalchemy import func, select, delete
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload, joinedload
from app.db.models.playlist import Playlist, PlaylistTrack
from app.db.models.audio import Track
from app.repositories.base import BaseRepository


class PlaylistRepository(BaseRepository[Playlist]):
    """Repository managing Playlist and PlaylistTrack persistence and queries."""

    def __init__(self, session: AsyncSession):
        super().__init__(Playlist, session)

    async def get_by_id_with_tracks(self, playlist_id: uuid.UUID) -> Optional[Playlist]:
        """
        Retrieves a playlist with its ordered tracks eagerly loaded
        to avoid N+1 query overhead.
        """
        stmt = (
            select(Playlist)
            .options(
                selectinload(Playlist.playlist_tracks).joinedload(PlaylistTrack.track)
            )
            .where(Playlist.id == playlist_id)
        )
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def list_by_owner(
        self, owner_id: uuid.UUID, skip: int = 0, limit: int = 50
    ) -> List[Playlist]:
        """
        Retrieves paginated playlists owned by a user, ordered by creation date descending,
        with tracks preloaded for count/duration calculations.
        """
        stmt = (
            select(Playlist)
            .options(
                selectinload(Playlist.playlist_tracks).joinedload(PlaylistTrack.track)
            )
            .where(Playlist.owner_id == owner_id)
            .order_by(Playlist.created_at.desc())
            .offset(skip)
            .limit(limit)
        )
        result = await self.session.execute(stmt)
        return list(result.scalars().all())

    async def list_by_owner_with_aggregates(
        self, owner_id: uuid.UUID, skip: int = 0, limit: int = 50
    ) -> List[tuple[Playlist, int, int]]:
        """
        Retrieves paginated playlists with track_count and duration_seconds pre-aggregated
        in a single SQL query, avoiding N+1 child queries and thousands of hydrated model objects.
        """
        stmt = (
            select(
                Playlist,
                func.count(PlaylistTrack.id).label("track_count"),
                func.coalesce(func.sum(Track.duration_seconds), 0).label(
                    "duration_seconds"
                ),
            )
            .outerjoin(PlaylistTrack, PlaylistTrack.playlist_id == Playlist.id)
            .outerjoin(Track, Track.id == PlaylistTrack.track_id)
            .where(Playlist.owner_id == owner_id)
            .group_by(Playlist.id)
            .order_by(Playlist.created_at.desc())
            .offset(skip)
            .limit(limit)
        )
        result = await self.session.execute(stmt)
        return [(row[0], int(row[1]), int(row[2])) for row in result.all()]

    async def get_max_position(self, playlist_id: uuid.UUID) -> int:
        """Returns the current highest position in the playlist, or -1 if empty."""
        stmt = select(func.coalesce(func.max(PlaylistTrack.position), -1)).where(
            PlaylistTrack.playlist_id == playlist_id
        )
        result = await self.session.execute(stmt)
        return result.scalar_one()

    async def get_playlist_track(
        self, playlist_id: uuid.UUID, track_id: uuid.UUID
    ) -> Optional[PlaylistTrack]:
        """Checks if a track already exists in a playlist."""
        stmt = select(PlaylistTrack).where(
            PlaylistTrack.playlist_id == playlist_id,
            PlaylistTrack.track_id == track_id,
        )
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def add_track(
        self, playlist_id: uuid.UUID, track_id: uuid.UUID, position: int
    ) -> PlaylistTrack:
        """Adds a track to the playlist at the specified position."""
        playlist_track = PlaylistTrack(
            playlist_id=playlist_id,
            track_id=track_id,
            position=position,
        )
        self.session.add(playlist_track)
        await self.session.flush()
        await self.session.refresh(playlist_track)
        return playlist_track

    async def remove_track_and_renumber(
        self, playlist_id: uuid.UUID, track_id: uuid.UUID
    ) -> bool:
        """
        Removes a track from a playlist and renumbers remaining track positions
        atomically to maintain continuous 0-indexed positions without gaps.
        """
        # 1. Delete the track membership
        stmt = delete(PlaylistTrack).where(
            PlaylistTrack.playlist_id == playlist_id,
            PlaylistTrack.track_id == track_id,
        )
        result = await self.session.execute(stmt)
        if result.rowcount == 0:
            return False

        # 2. Fetch remaining tracks ordered by current position
        remaining_stmt = (
            select(PlaylistTrack)
            .where(PlaylistTrack.playlist_id == playlist_id)
            .order_by(PlaylistTrack.position.asc())
        )
        remaining_res = await self.session.execute(remaining_stmt)
        remaining_tracks = list(remaining_res.scalars().all())

        # 3. Renumber positions
        for new_pos, pt in enumerate(remaining_tracks):
            pt.position = new_pos

        await self.session.flush()
        return True

    async def reorder_tracks(
        self, playlist_id: uuid.UUID, ordered_track_ids: List[uuid.UUID]
    ) -> None:
        """
        Atomically updates the positions of all tracks in a playlist
        according to the provided track ID order.
        """
        stmt = select(PlaylistTrack).where(PlaylistTrack.playlist_id == playlist_id)
        res = await self.session.execute(stmt)
        pts = list(res.scalars().all())

        pt_map = {pt.track_id: pt for pt in pts}

        # Apply new positions
        for new_pos, track_id in enumerate(ordered_track_ids):
            if track_id in pt_map:
                pt_map[track_id].position = new_pos

        await self.session.flush()
