import logging
import uuid
from datetime import datetime, timedelta, timezone
from typing import List, Optional
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.errors import BadRequestError, NotFoundError
from app.repositories.audio_repository import TrackRepository
from app.repositories.playback_repository import PlaybackRepository
from app.schemas.playback import (
    ListeningHistoryItemResponse,
    ListeningHistoryListResponse,
    PlaybackBatchEventsRequest,
    PlaybackBatchProgressResponse,
    PlaybackEventCreateRequest,
    PlaybackEventsIngestResponse,
    PlaybackProgressResponse,
    PlaybackProgressUpdateRequest,
    PlaybackTrackSummary,
    RecommendationListeningSignal,
)

logger = logging.getLogger("hums.playback")


class PlaybackService:
    """Service governing playback progress synchronization, event ingestion, and history retrieval."""

    def __init__(self, session: AsyncSession):
        self.session = session
        self.playback_repo = PlaybackRepository(session)
        self.track_repo = TrackRepository(session)

    async def get_progress(
        self, user_id: uuid.UUID, track_id: uuid.UUID
    ) -> PlaybackProgressResponse:
        """Retrieves progress for a specific track, defaulting to 0 position if never played."""
        record = await self.playback_repo.get_progress(user_id=user_id, track_id=track_id)
        if not record:
            return PlaybackProgressResponse(
                track_id=track_id,
                position_ms=0,
                duration_ms=0,
                completed=False,
                progress_percent=0.0,
                updated_at=datetime.now(timezone.utc),
            )
        return PlaybackProgressResponse(
            track_id=record.track_id,
            position_ms=record.position_ms,
            duration_ms=record.duration_ms,
            completed=record.completed,
            progress_percent=record.progress_percent,
            updated_at=record.updated_at,
        )

    async def get_progress_batch(
        self, user_id: uuid.UUID, track_ids: List[uuid.UUID]
    ) -> PlaybackBatchProgressResponse:
        """Retrieves progress for multiple tracks simultaneously."""
        records_map = await self.playback_repo.get_progress_batch(
            user_id=user_id, track_ids=track_ids
        )
        responses: List[PlaybackProgressResponse] = []
        for tid in track_ids:
            rec = records_map.get(tid)
            if rec:
                responses.append(
                    PlaybackProgressResponse(
                        track_id=rec.track_id,
                        position_ms=rec.position_ms,
                        duration_ms=rec.duration_ms,
                        completed=rec.completed,
                        progress_percent=rec.progress_percent,
                        updated_at=rec.updated_at,
                    )
                )
            else:
                responses.append(
                    PlaybackProgressResponse(
                        track_id=tid,
                        position_ms=0,
                        duration_ms=0,
                        completed=False,
                        progress_percent=0.0,
                        updated_at=datetime.now(timezone.utc),
                    )
                )
        return PlaybackBatchProgressResponse(items=responses)

    async def update_progress(
        self,
        user_id: uuid.UUID,
        track_id: uuid.UUID,
        payload: PlaybackProgressUpdateRequest,
    ) -> PlaybackProgressResponse:
        """Validates and persists a direct playback checkpoint update."""
        track = await self.track_repo.get_by_id(track_id)
        if not track:
            raise NotFoundError("Track not found", code="TRACK_NOT_FOUND")

        # Sanity check position bounds
        duration = payload.duration_ms or (track.duration_seconds * 1000 if track.duration_seconds else 0)
        pos = min(payload.position_ms, duration) if duration > 0 else payload.position_ms

        record = await self.playback_repo.upsert_progress(
            user_id=user_id,
            track_id=track_id,
            position_ms=pos,
            duration_ms=duration,
            completed=payload.completed,
        )
        await self.session.commit()

        return PlaybackProgressResponse(
            track_id=record.track_id,
            position_ms=record.position_ms,
            duration_ms=record.duration_ms,
            completed=record.completed,
            progress_percent=record.progress_percent,
            updated_at=record.updated_at,
        )

    def _validate_event_timestamp(self, played_at: datetime) -> None:
        """Ensures client event timestamp is reasonable to prevent clock drift poisoning."""
        now = datetime.now(timezone.utc)
        max_future = now + timedelta(days=1)
        max_past = now - timedelta(days=730)

        # Normalize timezone
        ts = played_at if played_at.tzinfo else played_at.replace(tzinfo=timezone.utc)

        if ts > max_future:
            raise BadRequestError(
                "Event timestamp is too far in the future.",
                code="INVALID_TIMESTAMP",
            )
        if ts < max_past:
            raise BadRequestError(
                "Event timestamp is older than maximum retention window.",
                code="INVALID_TIMESTAMP",
            )

    async def record_event(
        self, user_id: uuid.UUID, event: PlaybackEventCreateRequest
    ) -> PlaybackEventsIngestResponse:
        """Ingests a single playback event idempotently."""
        self._validate_event_timestamp(event.played_at)

        inserted, _ = await self.playback_repo.record_event(
            user_id=user_id, event_data=event
        )
        await self.session.commit()

        return PlaybackEventsIngestResponse(
            accepted_count=1 if inserted else 0,
            duplicate_count=0 if inserted else 1,
            message="Event accepted" if inserted else "Duplicate event ignored",
        )

    async def record_events_batch(
        self, user_id: uuid.UUID, batch: PlaybackBatchEventsRequest
    ) -> PlaybackEventsIngestResponse:
        """Ingests a batch of playback events (e.g. from offline sync) idempotently."""
        for ev in batch.events:
            self._validate_event_timestamp(ev.played_at)

        accepted, duplicates = await self.playback_repo.record_events_batch(
            user_id=user_id, events=batch.events
        )
        await self.session.commit()

        logger.info(
            f"Playback batch processed for user {user_id}: "
            f"accepted={accepted}, duplicates={duplicates}"
        )

        return PlaybackEventsIngestResponse(
            accepted_count=accepted,
            duplicate_count=duplicates,
            message=f"Batch processed: {accepted} accepted, {duplicates} duplicates ignored",
        )

    async def get_history(
        self, user_id: uuid.UUID, skip: int = 0, limit: int = 50
    ) -> ListeningHistoryListResponse:
        """Returns paginated listening history for user with preloaded track summaries."""
        bounded_limit = min(100, max(1, limit))
        records, total = await self.playback_repo.get_history(
            user_id=user_id, skip=skip, limit=bounded_limit
        )

        items: List[ListeningHistoryItemResponse] = []
        for r in records:
            track_summary = None
            if r.track:
                track_summary = PlaybackTrackSummary(
                    id=r.track.id,
                    owner_id=r.track.owner_id,
                    title=r.track.title,
                    description=r.track.description,
                    artist_name=r.track.artist_name,
                    album_name=r.track.album_name,
                    genre=r.track.genre,
                    duration_seconds=r.track.duration_seconds,
                    waveform_key=r.track.waveform_key,
                    status=r.track.status,
                    created_at=r.track.created_at,
                )

            items.append(
                ListeningHistoryItemResponse(
                    id=r.id,
                    track_id=r.track_id,
                    position_ms=r.position_ms,
                    duration_ms=r.duration_ms,
                    completed=r.completed,
                    progress_percent=r.progress_percent,
                    last_played_at=r.updated_at,
                    track=track_summary,
                )
            )

        has_more = (skip + len(items)) < total

        return ListeningHistoryListResponse(
            items=items,
            total=total,
            skip=skip,
            limit=bounded_limit,
            has_more=has_more,
        )

    async def delete_history_item(
        self, user_id: uuid.UUID, track_id: uuid.UUID
    ) -> bool:
        """Removes a specific track from the user's active listening history."""
        deleted = await self.playback_repo.delete_history_item(
            user_id=user_id, track_id=track_id
        )
        if deleted:
            await self.session.commit()
        return deleted

    async def clear_history(self, user_id: uuid.UUID) -> int:
        """Clears all tracks from user listening history."""
        count = await self.playback_repo.clear_history(user_id=user_id)
        if count > 0:
            await self.session.commit()
        return count

    async def get_listening_signals(
        self, user_id: uuid.UUID, limit: int = 50
    ) -> List[RecommendationListeningSignal]:
        """Provides clean listening signals to recommendation engines."""
        return await self.playback_repo.get_listening_signals(
            user_id=user_id, limit=limit
        )
