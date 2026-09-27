import uuid
from typing import Dict, List, Optional, Tuple
from sqlalchemy import delete, func, select, update
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import NotFoundError
from app.db.models.audio import Track
from app.db.models.like import UserTrackLike
from app.schemas.like import LikedTrackItem


class LikeRepository:
    """Repository handling database operations for track likes and personal library."""

    def __init__(self, db: AsyncSession):
        self.db = db

    async def like_track(self, user_id: uuid.UUID, track_id: uuid.UUID) -> Tuple[bool, int]:
        """
        Likes a track for a user idempotently.
        Atomically increments track likes_count if newly liked.
        Returns (is_liked, likes_count).
        """
        track = (
            await self.db.execute(select(Track).where(Track.id == track_id))
        ).scalar_one_or_none()
        if not track:
            raise NotFoundError("Track not found")

        stmt = (
            insert(UserTrackLike)
            .values(
                id=uuid.uuid4(),
                user_id=user_id,
                track_id=track_id,
            )
            .on_conflict_do_nothing(index_elements=["user_id", "track_id"])
            .returning(UserTrackLike.id)
        )
        res = await self.db.execute(stmt)
        inserted_id = res.scalar_one_or_none()

        if inserted_id:
            update_stmt = (
                update(Track)
                .where(Track.id == track_id)
                .values(likes_count=Track.likes_count + 1)
                .returning(Track.likes_count)
            )
            count_res = await self.db.execute(update_stmt)
            current_count = count_res.scalar_one()
            await self.db.commit()
            return True, current_count
        else:
            await self.db.commit()
            return True, track.likes_count

    async def unlike_track(self, user_id: uuid.UUID, track_id: uuid.UUID) -> Tuple[bool, int]:
        """
        Unlikes a track for a user idempotently.
        Atomically decrements track likes_count bounded by 0 if removed.
        Returns (is_liked, likes_count).
        """
        track = (
            await self.db.execute(select(Track).where(Track.id == track_id))
        ).scalar_one_or_none()
        if not track:
            raise NotFoundError("Track not found")

        delete_stmt = (
            delete(UserTrackLike)
            .where(
                UserTrackLike.user_id == user_id,
                UserTrackLike.track_id == track_id,
            )
            .returning(UserTrackLike.id)
        )
        res = await self.db.execute(delete_stmt)
        deleted_id = res.scalar_one_or_none()

        if deleted_id:
            update_stmt = (
                update(Track)
                .where(Track.id == track_id)
                .values(likes_count=func.greatest(0, Track.likes_count - 1))
                .returning(Track.likes_count)
            )
            count_res = await self.db.execute(update_stmt)
            current_count = count_res.scalar_one()
            await self.db.commit()
            return False, current_count
        else:
            await self.db.commit()
            return False, track.likes_count

    async def get_like_status(
        self, user_id: Optional[uuid.UUID], track_id: uuid.UUID
    ) -> Tuple[bool, int]:
        """
        Checks if a user likes a track and returns current likes_count.
        If user_id is None, is_liked is False.
        """
        track = (
            await self.db.execute(select(Track).where(Track.id == track_id))
        ).scalar_one_or_none()
        if not track:
            raise NotFoundError("Track not found")

        if not user_id:
            return False, track.likes_count

        like = (
            await self.db.execute(
                select(UserTrackLike).where(
                    UserTrackLike.user_id == user_id,
                    UserTrackLike.track_id == track_id,
                )
            )
        ).scalar_one_or_none()

        return like is not None, track.likes_count

    async def is_liked_batch(
        self, user_id: uuid.UUID, track_ids: List[uuid.UUID]
    ) -> Dict[uuid.UUID, bool]:
        """
        Resolves like status for a collection of track IDs in a single query.
        Prevents N+1 database queries.
        """
        if not track_ids:
            return {}

        stmt = select(UserTrackLike.track_id).where(
            UserTrackLike.user_id == user_id,
            UserTrackLike.track_id.in_(track_ids),
        )
        res = await self.db.execute(stmt)
        liked_set = {row[0] for row in res.fetchall()}
        return {tid: (tid in liked_set) for tid in track_ids}

    async def count_user_likes(self, user_id: uuid.UUID) -> int:
        """Counts total READY liked tracks for a user."""
        stmt = (
            select(func.count(UserTrackLike.id))
            .join(Track, UserTrackLike.track_id == Track.id)
            .where(
                UserTrackLike.user_id == user_id,
                Track.status == "READY",
            )
        )
        res = await self.db.execute(stmt)
        return res.scalar() or 0

    async def get_liked_tracks(
        self, user_id: uuid.UUID, page: int = 1, size: int = 20
    ) -> Tuple[List[LikedTrackItem], int]:
        """
        Retrieves paginated liked tracks for user ordered by liked_at DESC.
        Restricted to READY tracks.
        """
        # Count total
        count_stmt = (
            select(func.count(UserTrackLike.id))
            .join(Track, UserTrackLike.track_id == Track.id)
            .where(
                UserTrackLike.user_id == user_id,
                Track.status == "READY",
            )
        )
        total_res = await self.db.execute(count_stmt)
        total = total_res.scalar() or 0

        if total == 0:
            return [], 0

        # Query paginated tracks with liked_at
        offset = max(0, (page - 1) * size)
        list_stmt = (
            select(Track, UserTrackLike.created_at.label("liked_at"))
            .join(Track, UserTrackLike.track_id == Track.id)
            .where(
                UserTrackLike.user_id == user_id,
                Track.status == "READY",
            )
            .order_by(UserTrackLike.created_at.desc())
            .offset(offset)
            .limit(size)
        )
        res = await self.db.execute(list_stmt)
        items: List[LikedTrackItem] = []
        for track, liked_at in res.all():
            items.append(
                LikedTrackItem(
                    id=track.id,
                    title=track.title,
                    artist_name=track.artist_name,
                    album_name=track.album_name,
                    genre=track.genre,
                    duration_seconds=track.duration_seconds,
                    waveform_key=track.waveform_key,
                    status=track.status,
                    likes_count=track.likes_count,
                    is_liked=True,
                    liked_at=liked_at,
                    created_at=track.created_at,
                )
            )

        return items, total
