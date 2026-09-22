import uuid
from typing import List, Optional
from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload, joinedload
from app.db.models.audio import Track, AudioFile, AudioRendition, ProcessingJob
from app.repositories.base import BaseRepository


class TrackRepository(BaseRepository[Track]):
    """Repository managing Track persistence and relationship queries."""

    def __init__(self, session: AsyncSession):
        super().__init__(Track, session)

    async def get_by_id_with_relations(self, track_id: uuid.UUID) -> Optional[Track]:
        """Retrieves a track with its audio_files, renditions, and processing_jobs preloaded."""
        stmt = (
            select(Track)
            .options(
                selectinload(Track.audio_files),
                selectinload(Track.renditions),
                selectinload(Track.processing_jobs),
            )
            .where(Track.id == track_id)
        )
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_id_and_owner(
        self, track_id: uuid.UUID, owner_id: uuid.UUID
    ) -> Optional[Track]:
        """Retrieves a track by ID verifying owner identity."""
        stmt = (
            select(Track)
            .options(
                selectinload(Track.audio_files),
                selectinload(Track.renditions),
                selectinload(Track.processing_jobs),
            )
            .where(Track.id == track_id, Track.owner_id == owner_id)
        )
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def list_by_owner(
        self, owner_id: uuid.UUID, skip: int = 0, limit: int = 50
    ) -> List[Track]:
        """Retrieves tracks owned by a specific user ordered by creation date descending."""
        stmt = (
            select(Track)
            .options(
                selectinload(Track.audio_files),
                selectinload(Track.renditions),
                selectinload(Track.processing_jobs),
            )
            .where(Track.owner_id == owner_id)
            .order_by(Track.created_at.desc())
            .offset(skip)
            .limit(limit)
        )
        result = await self.session.execute(stmt)
        return list(result.scalars().all())

    async def update_status(self, track: Track, status: str) -> Track:
        """Updates the lifecycle status of a track."""
        track.status = status
        await self.session.flush()
        await self.session.refresh(track)
        return track

    async def update_metadata(
        self,
        track: Track,
        duration_seconds: Optional[int] = None,
        waveform_key: Optional[str] = None,
        status: Optional[str] = None,
    ) -> Track:
        """Updates duration, waveform key, and optional status of a track."""
        if duration_seconds is not None:
            track.duration_seconds = duration_seconds
        if waveform_key is not None:
            track.waveform_key = waveform_key
        if status is not None:
            track.status = status
        await self.session.flush()
        await self.session.refresh(track)
        return track

    async def list_popular_ready_tracks(
        self, limit: int = 20, exclude_ids: Optional[List[uuid.UUID]] = None
    ) -> List[Track]:
        """
        Retrieves top ready tracks sorted by platform popularity (playlist inclusion frequency),
        then by freshness (created_at DESC).
        """
        from app.db.models.playlist import PlaylistTrack
        stmt = (
            select(Track)
            .outerjoin(PlaylistTrack, Track.id == PlaylistTrack.track_id)
            .where(Track.status == "READY")
        )
        if exclude_ids:
            stmt = stmt.where(Track.id.not_in(exclude_ids))
        stmt = (
            stmt.group_by(Track.id)
            .order_by(func.count(PlaylistTrack.id).desc(), Track.created_at.desc())
            .limit(limit)
        )
        result = await self.session.execute(stmt)
        return list(result.scalars().all())

    async def list_recent_ready_tracks(
        self, limit: int = 20, exclude_ids: Optional[List[uuid.UUID]] = None
    ) -> List[Track]:
        """Retrieves most recently created ready tracks."""
        stmt = select(Track).where(Track.status == "READY")
        if exclude_ids:
            stmt = stmt.where(Track.id.not_in(exclude_ids))
        stmt = stmt.order_by(Track.created_at.desc()).limit(limit)
        result = await self.session.execute(stmt)
        return list(result.scalars().all())

    async def list_ready_by_genres(
        self, genres: List[str], limit: int = 20, exclude_ids: Optional[List[uuid.UUID]] = None
    ) -> List[Track]:
        """Retrieves ready tracks matching a list of genres."""
        if not genres:
            return []
        lower_genres = [g.lower() for g in genres]
        stmt = select(Track).where(
            Track.status == "READY",
            func.lower(Track.genre).in_(lower_genres)
        )
        if exclude_ids:
            stmt = stmt.where(Track.id.not_in(exclude_ids))
        stmt = stmt.order_by(Track.created_at.desc()).limit(limit)
        result = await self.session.execute(stmt)
        return list(result.scalars().all())

    async def list_ready_by_artists(
        self, artists: List[str], limit: int = 20, exclude_ids: Optional[List[uuid.UUID]] = None
    ) -> List[Track]:
        """Retrieves ready tracks matching a list of artists."""
        if not artists:
            return []
        lower_artists = [a.lower() for a in artists]
        stmt = select(Track).where(
            Track.status == "READY",
            func.lower(Track.artist_name).in_(lower_artists)
        )
        if exclude_ids:
            stmt = stmt.where(Track.id.not_in(exclude_ids))
        stmt = stmt.order_by(Track.created_at.desc()).limit(limit)
        result = await self.session.execute(stmt)
        return list(result.scalars().all())

    async def list_ready_tracks(
        self, skip: int = 0, limit: int = 50, exclude_ids: Optional[List[uuid.UUID]] = None
    ) -> List[Track]:
        """Retrieves paginated ready tracks."""
        stmt = select(Track).where(Track.status == "READY")
        if exclude_ids:
            stmt = stmt.where(Track.id.not_in(exclude_ids))
        stmt = stmt.order_by(Track.created_at.desc()).offset(skip).limit(limit)
        result = await self.session.execute(stmt)
        return list(result.scalars().all())


class AudioFileRepository(BaseRepository[AudioFile]):
    """Repository managing AudioFile persistence."""

    def __init__(self, session: AsyncSession):
        super().__init__(AudioFile, session)

    async def get_by_track_id(self, track_id: uuid.UUID) -> List[AudioFile]:
        """Retrieves all audio files associated with a track."""
        stmt = (
            select(AudioFile)
            .where(AudioFile.track_id == track_id)
            .order_by(AudioFile.created_at.desc())
        )
        result = await self.session.execute(stmt)
        return list(result.scalars().all())

    async def get_original_by_track_id(self, track_id: uuid.UUID) -> Optional[AudioFile]:
        """Retrieves the primary original audio file for a track."""
        stmt = (
            select(AudioFile)
            .where(AudioFile.track_id == track_id)
            .order_by(AudioFile.created_at.asc())
            .limit(1)
        )
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()


class AudioRenditionRepository(BaseRepository[AudioRendition]):
    """Repository managing AudioRendition persistence."""

    def __init__(self, session: AsyncSession):
        super().__init__(AudioRendition, session)

    async def get_by_track_id(self, track_id: uuid.UUID) -> List[AudioRendition]:
        """Retrieves all audio renditions associated with a track ordered by bitrate descending."""
        stmt = (
            select(AudioRendition)
            .where(AudioRendition.track_id == track_id)
            .order_by(AudioRendition.bitrate_kbps.desc())
        )
        result = await self.session.execute(stmt)
        return list(result.scalars().all())


class ProcessingJobRepository(BaseRepository[ProcessingJob]):
    """Repository managing ProcessingJob persistence."""

    def __init__(self, session: AsyncSession):
        super().__init__(ProcessingJob, session)

    async def get_by_id_with_track(self, job_id: uuid.UUID) -> Optional[ProcessingJob]:
        """Retrieves a processing job with its associated track."""
        stmt = (
            select(ProcessingJob)
            .options(joinedload(ProcessingJob.track))
            .where(ProcessingJob.id == job_id)
        )
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_track_id(self, track_id: uuid.UUID) -> List[ProcessingJob]:
        """Retrieves all processing jobs for a track."""
        stmt = (
            select(ProcessingJob)
            .where(ProcessingJob.track_id == track_id)
            .order_by(ProcessingJob.created_at.desc())
        )
        result = await self.session.execute(stmt)
        return list(result.scalars().all())

    async def get_latest_by_track_id(self, track_id: uuid.UUID) -> Optional[ProcessingJob]:
        """Retrieves the most recent processing job for a track."""
        stmt = (
            select(ProcessingJob)
            .where(ProcessingJob.track_id == track_id)
            .order_by(ProcessingJob.created_at.desc())
            .limit(1)
        )
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def claim_job_for_processing(
        self, track_id: uuid.UUID
    ) -> Optional[ProcessingJob]:
        """
        Atomically claims a pending or failed processing job for the given track.
        Sets status to 'PROCESSING' and increments attempts counter.
        Returns the claimed job, or None if no eligible job exists (e.g. already COMPLETED or PROCESSING).
        """
        # Select eligible job with FOR UPDATE to prevent race conditions
        subq = (
            select(ProcessingJob.id)
            .where(
                ProcessingJob.track_id == track_id,
                ProcessingJob.job_type == "AUDIO_TRANSCODE",
                ProcessingJob.status.in_(["PENDING", "FAILED"]),
            )
            .order_by(ProcessingJob.created_at.desc())
            .limit(1)
            .with_for_update(skip_locked=True)
            .scalar_subquery()
        )

        stmt = (
            update(ProcessingJob)
            .where(ProcessingJob.id == subq)
            .values(
                status="PROCESSING",
                attempts=ProcessingJob.attempts + 1,
                error_message=None,
            )
            .returning(ProcessingJob)
        )
        result = await self.session.execute(stmt)
        claimed_job = result.scalar_one_or_none()
        if claimed_job:
            await self.session.flush()
        return claimed_job

    async def update_status(
        self,
        job: ProcessingJob,
        status: str,
        error_message: Optional[str] = None,
    ) -> ProcessingJob:
        """Updates processing job status and optional error message."""
        job.status = status
        if error_message is not None:
            job.error_message = error_message
        await self.session.flush()
        await self.session.refresh(job)
        return job

