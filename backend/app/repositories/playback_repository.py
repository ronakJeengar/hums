import uuid
from datetime import datetime, timezone
from typing import Dict, List, Optional, Tuple
from sqlalchemy import case, delete, func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload
from app.db.models.audio import Track
from app.db.models.playback import PlaybackEvent, TrackPlaybackProgress
from app.repositories.base import BaseRepository
from app.schemas.playback import (
    PlaybackEventCreateRequest,
    PlaybackEventType,
    RecommendationListeningSignal,
)


class PlaybackRepository(BaseRepository[TrackPlaybackProgress]):
    """Repository managing playback progress states and idempotent event ingestion."""

    def __init__(self, session: AsyncSession):
        super().__init__(TrackPlaybackProgress, session)

    async def get_progress(
        self, user_id: uuid.UUID, track_id: uuid.UUID
    ) -> Optional[TrackPlaybackProgress]:
        """Retrieves current playback progress for a given user and track."""
        stmt = (
            select(TrackPlaybackProgress)
            .where(
                TrackPlaybackProgress.user_id == user_id,
                TrackPlaybackProgress.track_id == track_id,
            )
        )
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_progress_batch(
        self, user_id: uuid.UUID, track_ids: List[uuid.UUID]
    ) -> Dict[uuid.UUID, TrackPlaybackProgress]:
        """Retrieves playback progress for a list of track IDs."""
        if not track_ids:
            return {}
        stmt = (
            select(TrackPlaybackProgress)
            .where(
                TrackPlaybackProgress.user_id == user_id,
                TrackPlaybackProgress.track_id.in_(track_ids),
            )
        )
        result = await self.session.execute(stmt)
        records = result.scalars().all()
        return {record.track_id: record for record in records}

    async def upsert_progress(
        self,
        user_id: uuid.UUID,
        track_id: uuid.UUID,
        position_ms: int,
        duration_ms: int,
        completed: Optional[bool] = None,
        updated_at: Optional[datetime] = None,
    ) -> TrackPlaybackProgress:
        """Atomically inserts or updates a user's resume position and completion state for a track."""
        stmt = (
            select(TrackPlaybackProgress)
            .where(
                TrackPlaybackProgress.user_id == user_id,
                TrackPlaybackProgress.track_id == track_id,
            )
            .with_for_update()
        )
        result = await self.session.execute(stmt)
        record = result.scalar_one_or_none()

        now = updated_at or datetime.now(timezone.utc)

        # Completion rule: >= 95% progress completes the track
        is_completed: bool
        if completed is not None:
            is_completed = completed
        else:
            if duration_ms > 0 and position_ms >= int(duration_ms * 0.95):
                is_completed = True
            elif position_ms < int(duration_ms * 0.05):
                is_completed = False
            else:
                is_completed = record.completed if record else False

        if record:
            # High-water mark sync guard: only apply if the incoming update is >= existing timestamp
            if updated_at is None or record.updated_at is None or updated_at >= record.updated_at:
                record.position_ms = max(0, min(position_ms, duration_ms if duration_ms > 0 else position_ms))
                record.duration_ms = max(0, duration_ms)
                record.completed = is_completed
                record.updated_at = now
                await self.session.flush()
                await self.session.refresh(record)
            return record
        else:
            clamped_pos = max(0, min(position_ms, duration_ms if duration_ms > 0 else position_ms))
            record = TrackPlaybackProgress(
                user_id=user_id,
                track_id=track_id,
                position_ms=clamped_pos,
                duration_ms=max(0, duration_ms),
                completed=is_completed,
                created_at=now,
                updated_at=now,
            )
            self.session.add(record)
            await self.session.flush()
            await self.session.refresh(record)
            return record

    async def record_event(
        self, user_id: uuid.UUID, event_data: PlaybackEventCreateRequest
    ) -> Tuple[bool, Optional[PlaybackEvent]]:
        """Idempotently records a playback event.

        Returns (was_inserted, event). If the (user_id, event_id) already exists,
        returns (False, existing_event) without duplicating.
        """
        # 1. Check idempotency key (user_id, event_id)
        stmt = select(PlaybackEvent).where(
            PlaybackEvent.user_id == user_id,
            PlaybackEvent.event_id == event_data.event_id,
        )
        result = await self.session.execute(stmt)
        existing = result.scalar_one_or_none()
        if existing:
            return False, existing

        # 2. Insert new event
        event = PlaybackEvent(
            user_id=user_id,
            track_id=event_data.track_id,
            event_id=event_data.event_id,
            event_type=event_data.event_type.value if hasattr(event_data.event_type, "value") else str(event_data.event_type),
            position_ms=event_data.position_ms,
            duration_ms=event_data.duration_ms,
            source=event_data.source or "player",
            device_id=event_data.device_id,
            played_at=event_data.played_at,
        )
        self.session.add(event)
        await self.session.flush()

        # 3. Synchronize playback_progress
        is_completed = (
            True
            if event_data.event_type in (PlaybackEventType.COMPLETED, "COMPLETED")
            else None
        )
        # If PLAY_STARTED at 0, reset completion
        if (
            event_data.event_type in (PlaybackEventType.PLAY_STARTED, "PLAY_STARTED")
            and event_data.position_ms == 0
        ):
            is_completed = False

        await self.upsert_progress(
            user_id=user_id,
            track_id=event_data.track_id,
            position_ms=event_data.position_ms,
            duration_ms=event_data.duration_ms,
            completed=is_completed,
            updated_at=event_data.played_at,
        )

        return True, event

    async def record_events_batch(
        self, user_id: uuid.UUID, events: List[PlaybackEventCreateRequest]
    ) -> Tuple[int, int]:
        """Batched idempotent event ingestion sorted chronologically.

        Returns (accepted_count, duplicate_count).
        """
        # Sort chronologically so playback progression applies naturally
        sorted_events = sorted(events, key=lambda e: e.played_at)
        accepted = 0
        duplicates = 0

        for ev in sorted_events:
            inserted, _ = await self.record_event(user_id=user_id, event_data=ev)
            if inserted:
                accepted += 1
            else:
                duplicates += 1

        return accepted, duplicates

    async def get_history(
        self, user_id: uuid.UUID, skip: int = 0, limit: int = 50
    ) -> Tuple[List[TrackPlaybackProgress], int]:
        """Retrieves paginated listening history for user with preloaded tracks, avoiding N+1."""
        count_stmt = (
            select(func.count(TrackPlaybackProgress.id))
            .join(Track, Track.id == TrackPlaybackProgress.track_id)
            .where(
                TrackPlaybackProgress.user_id == user_id,
                Track.status.in_(["READY", "UPLOADED", "PROCESSING"]),
            )
        )
        total_result = await self.session.execute(count_stmt)
        total = total_result.scalar() or 0

        stmt = (
            select(TrackPlaybackProgress)
            .join(Track, Track.id == TrackPlaybackProgress.track_id)
            .options(joinedload(TrackPlaybackProgress.track))
            .where(
                TrackPlaybackProgress.user_id == user_id,
                Track.status.in_(["READY", "UPLOADED", "PROCESSING"]),
            )
            .order_by(TrackPlaybackProgress.updated_at.desc())
            .offset(skip)
            .limit(limit)
        )
        result = await self.session.execute(stmt)
        items = list(result.scalars().unique().all())
        return items, total

    async def delete_history_item(
        self, user_id: uuid.UUID, track_id: uuid.UUID
    ) -> bool:
        """Removes a track from the user's active listening history."""
        stmt = delete(TrackPlaybackProgress).where(
            TrackPlaybackProgress.user_id == user_id,
            TrackPlaybackProgress.track_id == track_id,
        )
        result = await self.session.execute(stmt)
        return result.rowcount > 0

    async def clear_history(self, user_id: uuid.UUID) -> int:
        """Clears all active listening history entries for the user."""
        stmt = delete(TrackPlaybackProgress).where(
            TrackPlaybackProgress.user_id == user_id
        )
        result = await self.session.execute(stmt)
        return result.rowcount

    async def get_listening_signals(
        self, user_id: uuid.UUID, limit: int = 50
    ) -> List[RecommendationListeningSignal]:
        """Aggregates listening patterns (plays, completions, duration) for recommendation feeds."""
        stmt = (
            select(
                PlaybackEvent.track_id,
                func.count(PlaybackEvent.id).label("play_count"),
                func.sum(
                    case((PlaybackEvent.event_type == "COMPLETED", 1), else_=0)
                ).label("completion_count"),
                func.sum(PlaybackEvent.position_ms).label("total_duration"),
                func.max(PlaybackEvent.played_at).label("last_played_at"),
            )
            .where(PlaybackEvent.user_id == user_id)
            .group_by(PlaybackEvent.track_id)
            .order_by(func.max(PlaybackEvent.played_at).desc())
            .limit(limit)
        )
        result = await self.session.execute(stmt)
        rows = result.all()

        # Also get current completed status from progress
        track_ids = [r.track_id for r in rows]
        progress_map = await self.get_progress_batch(user_id=user_id, track_ids=track_ids)

        signals: List[RecommendationListeningSignal] = []
        for r in rows:
            prog = progress_map.get(r.track_id)
            signals.append(
                RecommendationListeningSignal(
                    track_id=r.track_id,
                    play_count=r.play_count or 0,
                    completion_count=r.completion_count or 0,
                    total_duration_listened_ms=r.total_duration or 0,
                    last_played_at=r.last_played_at,
                    completed=prog.completed if prog else False,
                )
            )
        return signals
