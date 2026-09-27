import uuid
from datetime import datetime, timezone
from typing import Any, List, Optional, Tuple

from sqlalchemy import and_, case, delete, func, or_, select, update
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.db.models.audio import Track
from app.db.models.creator import Creator, CreatorFollower
from app.db.models.playlist import Playlist
from app.db.models.user import User
from app.repositories.base import BaseRepository


class CreatorRepository(BaseRepository[Creator]):
    """
    Repository for Creator and CreatorFollower entities.
    Handles creator lookups, follow/unfollow concurrency, and creator content queries.
    """

    def __init__(self, session: AsyncSession):
        super().__init__(Creator, session)

    async def get_by_id(self, creator_id: uuid.UUID) -> Optional[Creator]:
        """Retrieves a creator profile by UUID."""
        stmt = select(Creator).where(Creator.id == creator_id)
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_user_id(self, user_id: uuid.UUID) -> Optional[Creator]:
        """Retrieves a creator profile linked to an authenticated user ID."""
        stmt = select(Creator).where(Creator.user_id == user_id)
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_name(self, name: str) -> Optional[Creator]:
        """Looks up a creator by case-insensitive name match."""
        stmt = select(Creator).where(func.lower(Creator.name) == name.strip().lower())
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_username(self, username: str) -> Optional[Creator]:
        """Looks up a creator by case-insensitive username match."""
        stmt = select(Creator).where(func.lower(Creator.username) == username.strip().lower())
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_or_create_by_name(
        self,
        name: str,
        user_id: Optional[uuid.UUID] = None,
        avatar_url: Optional[str] = None,
        bio: Optional[str] = None,
    ) -> Creator:
        """
        Retrieves an existing creator by name or atomically creates a new one.
        Guarantees that catalog or user artists resolve to a real creator entity.
        """
        clean_name = name.strip()
        existing = await self.get_by_name(clean_name)
        if existing:
            if user_id and existing.user_id is None:
                existing.user_id = user_id
                if avatar_url and not existing.avatar_url:
                    existing.avatar_url = avatar_url
                if bio and not existing.bio:
                    existing.bio = bio
                await self.session.flush()
                await self.session.refresh(existing)
            return existing

        creator = Creator(
            name=clean_name,
            user_id=user_id,
            avatar_url=avatar_url,
            bio=bio,
            followers_count=0,
            is_verified=False,
        )
        self.session.add(creator)
        await self.session.flush()
        await self.session.refresh(creator)
        return creator

    async def is_following(self, user_id: uuid.UUID, creator_id: uuid.UUID) -> bool:
        """Checks if a user is currently following a creator."""
        stmt = (
            select(func.count(CreatorFollower.id))
            .where(
                CreatorFollower.user_id == user_id,
                CreatorFollower.creator_id == creator_id,
            )
        )
        result = await self.session.execute(stmt)
        count = result.scalar() or 0
        return count > 0

    async def is_following_batch(
        self,
        user_id: uuid.UUID,
        creator_ids: List[uuid.UUID],
    ) -> dict[uuid.UUID, bool]:
        """
        Checks following status for a batch of creator IDs in a single query.
        Prevents N+1 queries in search and list views.
        """
        if not creator_ids:
            return {}
        stmt = (
            select(CreatorFollower.creator_id)
            .where(
                CreatorFollower.user_id == user_id,
                CreatorFollower.creator_id.in_(creator_ids),
            )
        )
        result = await self.session.execute(stmt)
        followed_set = set(result.scalars().all())
        return {cid: (cid in followed_set) for cid in creator_ids}

    async def follow_creator(
        self,
        user_id: uuid.UUID,
        creator_id: uuid.UUID,
    ) -> Tuple[bool, int]:
        """
        Follows a creator atomically.
        Uses PostgreSQL ON CONFLICT DO NOTHING to prevent duplicate follows.
        Returns: (was_newly_followed: bool, updated_followers_count: int)
        """
        stmt = (
            pg_insert(CreatorFollower)
            .values(user_id=user_id, creator_id=creator_id)
            .on_conflict_do_nothing(index_elements=["user_id", "creator_id"])
            .returning(CreatorFollower.id)
        )
        res = await self.session.execute(stmt)
        inserted_id = res.scalar_one_or_none()

        if inserted_id is not None:
            # Increment follower count atomically
            up_stmt = (
                update(Creator)
                .where(Creator.id == creator_id)
                .values(followers_count=Creator.followers_count + 1)
                .returning(Creator.followers_count)
            )
            up_res = await self.session.execute(up_stmt)
            count = up_res.scalar_one()
            await self.session.flush()
            return True, count
        else:
            # Already following - return current count without incrementing
            creator = await self.get_by_id(creator_id)
            return False, creator.followers_count if creator else 0

    async def unfollow_creator(
        self,
        user_id: uuid.UUID,
        creator_id: uuid.UUID,
    ) -> Tuple[bool, int]:
        """
        Unfollows a creator atomically.
        Guarantees follower_count never decrements below 0.
        Returns: (was_unfollowed: bool, updated_followers_count: int)
        """
        del_stmt = (
            delete(CreatorFollower)
            .where(
                CreatorFollower.user_id == user_id,
                CreatorFollower.creator_id == creator_id,
            )
            .returning(CreatorFollower.id)
        )
        res = await self.session.execute(del_stmt)
        deleted_id = res.scalar_one_or_none()

        if deleted_id is not None:
            up_stmt = (
                update(Creator)
                .where(Creator.id == creator_id)
                .values(
                    followers_count=case(
                        (Creator.followers_count > 0, Creator.followers_count - 1),
                        else_=0,
                    )
                )
                .returning(Creator.followers_count)
            )
            up_res = await self.session.execute(up_stmt)
            count = up_res.scalar_one()
            await self.session.flush()
            return True, count
        else:
            # Wasn't following - return current count without modifying
            creator = await self.get_by_id(creator_id)
            return False, creator.followers_count if creator else 0

    async def get_followers(
        self,
        creator_id: uuid.UUID,
        page: int = 1,
        size: int = 20,
    ) -> Tuple[List[Tuple[User, datetime]], int]:
        """
        Retrieves paginated followers of a creator with their user profiles and follow timestamps.
        """
        offset = (page - 1) * size

        # Count total followers
        count_stmt = (
            select(func.count(CreatorFollower.id))
            .where(CreatorFollower.creator_id == creator_id)
        )
        count_res = await self.session.execute(count_stmt)
        total = count_res.scalar() or 0

        if total == 0:
            return [], 0

        # Query followers joined with User
        stmt = (
            select(User, CreatorFollower.created_at)
            .join(User, CreatorFollower.user_id == User.id)
            .where(CreatorFollower.creator_id == creator_id)
            .order_by(CreatorFollower.created_at.desc())
            .offset(offset)
            .limit(size)
        )
        res = await self.session.execute(stmt)
        items = [(row[0], row[1]) for row in res.all()]
        return items, total

    async def get_following(
        self,
        user_id: uuid.UUID,
        page: int = 1,
        size: int = 20,
    ) -> Tuple[List[Creator], int]:
        """
        Retrieves paginated creators followed by a user.
        """
        offset = (page - 1) * size

        count_stmt = (
            select(func.count(CreatorFollower.id))
            .where(CreatorFollower.user_id == user_id)
        )
        count_res = await self.session.execute(count_stmt)
        total = count_res.scalar() or 0

        if total == 0:
            return [], 0

        stmt = (
            select(Creator)
            .join(CreatorFollower, Creator.id == CreatorFollower.creator_id)
            .where(CreatorFollower.user_id == user_id)
            .order_by(CreatorFollower.created_at.desc())
            .offset(offset)
            .limit(size)
        )
        res = await self.session.execute(stmt)
        creators = list(res.scalars().all())
        return creators, total

    async def get_following_creator_ids(self, user_id: uuid.UUID) -> List[uuid.UUID]:
        """Returns all creator IDs followed by a user (for recommendations/signals)."""
        stmt = (
            select(CreatorFollower.creator_id)
            .where(CreatorFollower.user_id == user_id)
        )
        res = await self.session.execute(stmt)
        return list(res.scalars().all())

    async def get_follower_user_ids(self, creator_id: uuid.UUID) -> List[uuid.UUID]:
        """Returns all user IDs following a creator (for notification fan-out)."""
        stmt = (
            select(CreatorFollower.user_id)
            .where(CreatorFollower.creator_id == creator_id)
        )
        res = await self.session.execute(stmt)
        return list(res.scalars().all())

    async def get_creator_tracks(
        self,
        creator: Creator,
        limit: int = 10,
        popular: bool = False,
    ) -> List[Track]:
        """
        Retrieves tracks associated with a creator.
        Matches by creator_id, creator user_id, or track artist_name.
        """
        filters = [Track.status == "READY"]
        or_conds = [Track.creator_id == creator.id]
        if creator.user_id:
            or_conds.append(Track.owner_id == creator.user_id)
        if creator.name:
            or_conds.append(func.lower(Track.artist_name) == creator.name.strip().lower())
        filters.append(or_(*or_conds))

        stmt = (
            select(Track)
            .options(
                selectinload(Track.audio_files),
                selectinload(Track.processing_jobs),
                selectinload(Track.renditions),
            )
            .where(and_(*filters))
        )

        if popular:
            # Order by duration or created_at desc (can be enhanced with playback count)
            stmt = stmt.order_by(Track.created_at.desc(), Track.id.desc())
        else:
            stmt = stmt.order_by(Track.created_at.desc(), Track.id.desc())

        stmt = stmt.limit(limit)
        res = await self.session.execute(stmt)
        return list(res.scalars().all())

    async def get_creator_track_count(self, creator: Creator) -> int:
        """Counts total READY tracks for a creator."""
        filters = [Track.status == "READY"]
        or_conds = [Track.creator_id == creator.id]
        if creator.user_id:
            or_conds.append(Track.owner_id == creator.user_id)
        if creator.name:
            or_conds.append(func.lower(Track.artist_name) == creator.name.strip().lower())
        filters.append(or_(*or_conds))

        stmt = select(func.count(Track.id)).where(and_(*filters))
        res = await self.session.execute(stmt)
        return res.scalar() or 0

    async def get_creator_albums(self, creator_name: str) -> List[dict[str, Any]]:
        """
        Aggregates distinct albums released by this creator.
        """
        if not creator_name:
            return []
        stmt = (
            select(
                Track.album_name,
                func.count(Track.id).label("track_count"),
            )
            .where(
                Track.status == "READY",
                func.lower(Track.artist_name) == creator_name.strip().lower(),
                Track.album_name.isnot(None),
                Track.album_name != "",
            )
            .group_by(Track.album_name)
            .order_by(func.count(Track.id).desc())
            .limit(10)
        )
        res = await self.session.execute(stmt)
        albums: List[dict[str, Any]] = []
        for album_name, count in res.all():
            album_id = f"album_{uuid.uuid5(uuid.NAMESPACE_DNS, f'{creator_name.lower()}:{album_name.lower()}')}"
            albums.append({
                "id": album_id,
                "title": album_name,
                "artist_name": creator_name,
                "track_count": count or 0,
                "cover_image_key": None,
                "cover_image_url": None,
            })
        return albums

    async def get_creator_playlists(self, user_id: Optional[uuid.UUID]) -> List[Playlist]:
        """Retrieves public playlists authored by the creator user."""
        if not user_id:
            return []
        stmt = (
            select(Playlist)
            .options(selectinload(Playlist.playlist_tracks))
            .where(
                Playlist.owner_id == user_id,
                Playlist.is_public == True,
            )
            .order_by(Playlist.created_at.desc())
            .limit(10)
        )
        res = await self.session.execute(stmt)
        return list(res.scalars().all())

    async def list_creators(
        self,
        skip: int = 0,
        limit: int = 20,
    ) -> Tuple[List[Creator], int]:
        """Lists creators ordered by followers count descending."""
        count_stmt = select(func.count(Creator.id))
        count_res = await self.session.execute(count_stmt)
        total = count_res.scalar() or 0

        stmt = (
            select(Creator)
            .order_by(Creator.followers_count.desc(), Creator.created_at.desc())
            .offset(skip)
            .limit(limit)
        )
        res = await self.session.execute(stmt)
        return list(res.scalars().all()), total
