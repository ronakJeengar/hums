import uuid
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, List, Optional, Tuple
from sqlalchemy import desc, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.db.models.admin import CreatorApplication
from app.db.models.audio import Track
from app.db.models.creator import Creator
from app.db.models.playback import PlaybackEvent


class CreatorStudioRepository:
    """Data access layer for Creator Studio dashboard, track management, and analytics."""

    def __init__(self, session: AsyncSession):
        self.session = session

    async def get_dashboard_stats(self, user_id: uuid.UUID) -> Dict[str, Any]:
        """Calculates creator-scoped statistics from actual database records."""
        # Tracks count by status
        tracks_res = (
            await self.session.execute(
                select(Track.status, func.count())
                .where(Track.owner_id == user_id)
                .group_by(Track.status)
            )
        ).all()
        status_map = {status: count for status, count in tracks_res}

        published_tracks = status_map.get("READY", 0)
        processing_tracks = status_map.get("PROCESSING", 0) + status_map.get("UPLOADED", 0)
        failed_uploads = status_map.get("FAILED", 0)

        # Total likes
        likes_sum = (
            await self.session.execute(
                select(func.coalesce(func.sum(Track.likes_count), 0))
                .where(Track.owner_id == user_id)
            )
        ).scalar() or 0

        # Follower count from creator profile
        creator = (
            await self.session.execute(
                select(Creator).where(Creator.user_id == user_id)
            )
        ).scalar_one_or_none()
        follower_count = creator.followers_count if creator else 0

        # Total plays across all creator's tracks
        total_plays = (
            await self.session.execute(
                select(func.count())
                .select_from(PlaybackEvent)
                .join(Track, PlaybackEvent.track_id == Track.id)
                .where(
                    Track.owner_id == user_id,
                    PlaybackEvent.event_type.in_(["start", "complete"]),
                )
            )
        ).scalar() or 0

        # Top 5 tracks by plays
        top_tracks_query = (
            select(Track, func.count(PlaybackEvent.id).label("plays"))
            .outerjoin(
                PlaybackEvent,
                (PlaybackEvent.track_id == Track.id)
                & (PlaybackEvent.event_type.in_(["start", "complete"])),
            )
            .where(Track.owner_id == user_id)
            .group_by(Track.id)
            .order_by(desc("plays"), desc(Track.likes_count))
            .limit(5)
        )
        top_tracks_res = (await self.session.execute(top_tracks_query)).all()
        top_tracks = [
            {
                "id": t.id,
                "title": t.title,
                "artist_name": t.artist_name,
                "album_name": t.album_name,
                "genre": t.genre,
                "duration_seconds": t.duration_seconds,
                "status": t.status,
                "likes_count": t.likes_count,
                "play_count": plays,
                "created_at": t.created_at,
                "waveform_key": t.waveform_key,
            }
            for t, plays in top_tracks_res
        ]

        # Recent 5 uploads
        recent_tracks = (
            await self.session.execute(
                select(Track)
                .where(Track.owner_id == user_id)
                .order_by(desc(Track.created_at))
                .limit(5)
            )
        ).scalars().all()
        recent_uploads = [
            {
                "id": t.id,
                "title": t.title,
                "artist_name": t.artist_name,
                "album_name": t.album_name,
                "genre": t.genre,
                "duration_seconds": t.duration_seconds,
                "status": t.status,
                "likes_count": t.likes_count,
                "play_count": 0,
                "created_at": t.created_at,
                "waveform_key": t.waveform_key,
            }
            for t in recent_tracks
        ]

        return {
            "published_tracks": published_tracks,
            "processing_tracks": processing_tracks,
            "failed_uploads": failed_uploads,
            "total_plays": total_plays,
            "follower_count": follower_count,
            "total_likes": likes_sum,
            "top_tracks": top_tracks,
            "recent_uploads": recent_uploads,
        }

    async def list_tracks(
        self,
        user_id: uuid.UUID,
        page: int = 1,
        size: int = 20,
        status: Optional[str] = None,
        search: Optional[str] = None,
    ) -> Tuple[List[Dict[str, Any]], int]:
        """Lists tracks owned by the authenticated creator with play counts."""
        query = select(Track).where(Track.owner_id == user_id)

        if status:
            query = query.where(Track.status == status)

        if search:
            pat = f"%{search.strip().lower()}%"
            query = query.where(
                or_(
                    func.lower(Track.title).like(pat),
                    func.lower(Track.album_name).like(pat),
                    func.lower(Track.genre).like(pat),
                )
            )

        count_query = select(func.count()).select_from(query.subquery())
        total = (await self.session.execute(count_query)).scalar() or 0

        offset = (page - 1) * size
        query = query.order_by(desc(Track.created_at)).offset(offset).limit(size)
        tracks = (await self.session.execute(query)).scalars().all()

        track_ids = [t.id for t in tracks]
        play_counts: Dict[uuid.UUID, int] = {}
        if track_ids:
            plays_res = (
                await self.session.execute(
                    select(PlaybackEvent.track_id, func.count())
                    .where(
                        PlaybackEvent.track_id.in_(track_ids),
                        PlaybackEvent.event_type.in_(["start", "complete"]),
                    )
                    .group_by(PlaybackEvent.track_id)
                )
            ).all()
            play_counts = {tid: count for tid, count in plays_res}

        result = [
            {
                "id": t.id,
                "title": t.title,
                "artist_name": t.artist_name,
                "album_name": t.album_name,
                "genre": t.genre,
                "duration_seconds": t.duration_seconds,
                "status": t.status,
                "likes_count": t.likes_count,
                "play_count": play_counts.get(t.id, 0),
                "created_at": t.created_at,
                "waveform_key": t.waveform_key,
            }
            for t in tracks
        ]
        return result, total

    async def get_track(self, user_id: uuid.UUID, track_id: uuid.UUID) -> Optional[Track]:
        """Fetches track ensuring strict creator ownership."""
        return (
            await self.session.execute(
                select(Track).where(Track.id == track_id, Track.owner_id == user_id)
            )
        ).scalar_one_or_none()

    async def update_track(
        self,
        user_id: uuid.UUID,
        track_id: uuid.UUID,
        update_data: Dict[str, Any],
    ) -> Optional[Track]:
        """Updates track metadata for an owned track."""
        track = await self.get_track(user_id, track_id)
        if not track:
            return None

        for field in ("title", "artist_name", "album_name", "genre", "description"):
            if field in update_data and update_data[field] is not None:
                setattr(track, field, update_data[field])

        await self.session.commit()
        await self.session.refresh(track)
        return track

    async def get_analytics(
        self,
        user_id: uuid.UUID,
        period_days: int = 30,
    ) -> Dict[str, Any]:
        """Aggregates playback metrics over time for creator's tracks."""
        start_date = datetime.now(timezone.utc) - timedelta(days=period_days)

        # Total plays and unique listeners
        summary_query = (
            select(
                func.count(PlaybackEvent.id).label("total_plays"),
                func.count(func.distinct(PlaybackEvent.user_id)).label("unique_listeners"),
            )
            .join(Track, PlaybackEvent.track_id == Track.id)
            .where(
                Track.owner_id == user_id,
                PlaybackEvent.played_at >= start_date,
                PlaybackEvent.event_type.in_(["start", "complete"]),
            )
        )
        summary = (await self.session.execute(summary_query)).one()
        total_plays = summary.total_plays or 0
        unique_listeners = summary.unique_listeners or 0

        # Timeline grouped by date
        timeline_query = (
            select(
                func.date_trunc("day", PlaybackEvent.played_at).label("day"),
                func.count(PlaybackEvent.id).label("plays"),
            )
            .join(Track, PlaybackEvent.track_id == Track.id)
            .where(
                Track.owner_id == user_id,
                PlaybackEvent.played_at >= start_date,
                PlaybackEvent.event_type.in_(["start", "complete"]),
            )
            .group_by("day")
            .order_by("day")
        )
        timeline_res = (await self.session.execute(timeline_query)).all()
        plays_timeline = [
            {"date": str(day).split(" ")[0], "plays": plays}
            for day, plays in timeline_res
        ]

        # Sources breakdown
        sources_query = (
            select(PlaybackEvent.source, func.count(PlaybackEvent.id))
            .join(Track, PlaybackEvent.track_id == Track.id)
            .where(
                Track.owner_id == user_id,
                PlaybackEvent.played_at >= start_date,
            )
            .group_by(PlaybackEvent.source)
        )
        sources_res = (await self.session.execute(sources_query)).all()
        sources_breakdown = {source or "direct": count for source, count in sources_res}

        # Top 5 tracks in period
        top_query = (
            select(Track.id, Track.title, func.count(PlaybackEvent.id).label("plays"))
            .join(PlaybackEvent, PlaybackEvent.track_id == Track.id)
            .where(
                Track.owner_id == user_id,
                PlaybackEvent.played_at >= start_date,
                PlaybackEvent.event_type.in_(["start", "complete"]),
            )
            .group_by(Track.id, Track.title)
            .order_by(desc("plays"))
            .limit(5)
        )
        top_res = (await self.session.execute(top_query)).all()
        top_tracks = [
            {"track_id": tid, "title": title, "plays": plays}
            for tid, title, plays in top_res
        ]

        return {
            "period": f"{period_days}d",
            "total_plays": total_plays,
            "unique_listeners": unique_listeners,
            "plays_timeline": plays_timeline,
            "top_tracks": top_tracks,
            "sources_breakdown": sources_breakdown,
        }

    async def get_profile(self, user_id: uuid.UUID) -> Optional[Creator]:
        """Fetches linked Creator entity for user."""
        return (
            await self.session.execute(
                select(Creator).where(Creator.user_id == user_id)
            )
        ).scalar_one_or_none()

    async def update_profile(
        self,
        user_id: uuid.UUID,
        name: Optional[str] = None,
        bio: Optional[str] = None,
        avatar_url: Optional[str] = None,
        cover_image_url: Optional[str] = None,
    ) -> Optional[Creator]:
        """Updates creator profile fields."""
        creator = await self.get_profile(user_id)
        if not creator:
            return None

        if name is not None:
            creator.name = name
        if bio is not None:
            creator.bio = bio
        if avatar_url is not None:
            creator.avatar_url = avatar_url
        if cover_image_url is not None:
            creator.cover_image_url = cover_image_url

        await self.session.commit()
        await self.session.refresh(creator)
        return creator

    async def create_application(
        self,
        user_id: uuid.UUID,
        artist_name: str,
        bio: Optional[str] = None,
        genres: Optional[str] = None,
        portfolio_url: Optional[str] = None,
    ) -> CreatorApplication:
        """Creates a pending application for listener to become creator."""
        app = CreatorApplication(
            id=uuid.uuid4(),
            user_id=user_id,
            artist_name=artist_name,
            bio=bio,
            genres=genres,
            portfolio_url=portfolio_url,
            status="PENDING",
        )
        self.session.add(app)
        await self.session.commit()
        await self.session.refresh(app)
        return app

    async def get_application_by_user(
        self,
        user_id: uuid.UUID,
    ) -> Optional[CreatorApplication]:
        """Fetches most recent creator application for user."""
        return (
            await self.session.execute(
                select(CreatorApplication)
                .where(CreatorApplication.user_id == user_id)
                .order_by(desc(CreatorApplication.created_at))
                .limit(1)
            )
        ).scalar_one_or_none()
