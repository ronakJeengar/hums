import uuid
from typing import List, Optional
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload, joinedload
from app.db.models.audio import Track, AudioFile, ProcessingJob
from app.repositories.base import BaseRepository


class TrackRepository(BaseRepository[Track]):
    """Repository managing Track persistence and relationship queries."""

    def __init__(self, session: AsyncSession):
        super().__init__(Track, session)

    async def get_by_id_with_relations(self, track_id: uuid.UUID) -> Optional[Track]:
        """Retrieves a track with its audio_files and processing_jobs preloaded."""
        stmt = (
            select(Track)
            .options(
                selectinload(Track.audio_files),
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
