import uuid
from typing import Any, Dict, List, Optional, Tuple

from app.core.errors import ForbiddenError, NotFoundError, ValidationError
from app.db.models.admin import ContentReport, CreatorApplication
from app.db.models.creator import Creator
from app.repositories.creator_studio_repository import CreatorStudioRepository
from app.schemas.creator_studio import (
    CreatorAnalyticsResponse,
    CreatorDashboardStats,
    CreatorStudioProfile,
    CreatorTrackItem,
)


class CreatorStudioService:
    """Business logic for Creator Studio content management, analytics, and applications."""

    def __init__(self, studio_repo: CreatorStudioRepository):
        self.studio_repo = studio_repo

    async def get_dashboard(self, user_id: uuid.UUID) -> CreatorDashboardStats:
        """Calculates and returns creator dashboard stats."""
        raw = await self.studio_repo.get_dashboard_stats(user_id)
        return CreatorDashboardStats(
            published_tracks=raw["published_tracks"],
            processing_tracks=raw["processing_tracks"],
            failed_uploads=raw["failed_uploads"],
            total_plays=raw["total_plays"],
            follower_count=raw["follower_count"],
            total_likes=raw["total_likes"],
            top_tracks=[CreatorTrackItem.model_validate(t) for t in raw["top_tracks"]],
            recent_uploads=[CreatorTrackItem.model_validate(t) for t in raw["recent_uploads"]],
        )

    async def list_tracks(
        self,
        user_id: uuid.UUID,
        page: int = 1,
        size: int = 20,
        status: Optional[str] = None,
        search: Optional[str] = None,
    ) -> Tuple[List[CreatorTrackItem], int]:
        """Lists tracks owned by the authenticated creator."""
        items, total = await self.studio_repo.list_tracks(
            user_id=user_id,
            page=page,
            size=size,
            status=status,
            search=search,
        )
        return [CreatorTrackItem.model_validate(t) for t in items], total

    async def update_track(
        self,
        user_id: uuid.UUID,
        track_id: uuid.UUID,
        update_data: Dict[str, Any],
    ) -> CreatorTrackItem:
        """Updates track metadata with strict ownership enforcement."""
        track = await self.studio_repo.update_track(
            user_id=user_id,
            track_id=track_id,
            update_data=update_data,
        )
        if not track:
            raise NotFoundError(
                f"Track {track_id} not found or you do not have permission to edit it.",
                code="TRACK_NOT_FOUND_OR_FORBIDDEN",
            )
        return CreatorTrackItem.model_validate(track)

    async def retry_processing(
        self,
        user_id: uuid.UUID,
        track_id: uuid.UUID,
    ) -> Dict[str, str]:
        """Retries transcoding for a failed track owned by the creator."""
        track = await self.studio_repo.get_track(user_id, track_id)
        if not track:
            raise NotFoundError(
                f"Track {track_id} not found or not owned by you.",
                code="TRACK_NOT_FOUND",
            )

        # Update status
        track.status = "PROCESSING"
        await self.studio_repo.session.commit()

        # Trigger celery
        try:
            from app.workers.tasks import transcode_audio_track
            transcode_audio_track.delay(str(track_id))
        except Exception:
            pass

        return {"message": "Track processing retry queued successfully."}

    async def get_analytics(
        self,
        user_id: uuid.UUID,
        period: str = "30d",
    ) -> CreatorAnalyticsResponse:
        """Aggregates playback events and listening metrics."""
        days = 30
        if period == "7d":
            days = 7
        elif period == "90d":
            days = 90

        raw = await self.studio_repo.get_analytics(user_id=user_id, period_days=days)
        return CreatorAnalyticsResponse(
            period=raw["period"],
            total_plays=raw["total_plays"],
            unique_listeners=raw["unique_listeners"],
            plays_timeline=raw["plays_timeline"],
            top_tracks=raw["top_tracks"],
            sources_breakdown=raw["sources_breakdown"],
        )

    async def get_profile(self, user_id: uuid.UUID) -> CreatorStudioProfile:
        """Retrieves creator profile for user."""
        creator = await self.studio_repo.get_profile(user_id)
        if not creator:
            # Auto-provision profile shell if user has creator privileges
            creator = Creator(
                id=uuid.uuid4(),
                user_id=user_id,
                name="New Creator",
                followers_count=0,
                is_verified=False,
            )
            self.studio_repo.session.add(creator)
            await self.studio_repo.session.commit()
            await self.studio_repo.session.refresh(creator)

        return CreatorStudioProfile.model_validate(creator)

    async def update_profile(
        self,
        user_id: uuid.UUID,
        name: Optional[str] = None,
        bio: Optional[str] = None,
        avatar_url: Optional[str] = None,
        cover_image_url: Optional[str] = None,
    ) -> CreatorStudioProfile:
        """Updates creator profile details."""
        creator = await self.studio_repo.update_profile(
            user_id=user_id,
            name=name,
            bio=bio,
            avatar_url=avatar_url,
            cover_image_url=cover_image_url,
        )
        if not creator:
            raise NotFoundError("Creator profile not found.", code="CREATOR_NOT_FOUND")
        return CreatorStudioProfile.model_validate(creator)

    async def submit_application(
        self,
        user_id: uuid.UUID,
        artist_name: str,
        bio: Optional[str] = None,
        genres: Optional[str] = None,
        portfolio_url: Optional[str] = None,
    ) -> CreatorApplication:
        """Submits an application to join the creator program."""
        existing = await self.studio_repo.get_application_by_user(user_id)
        if existing and existing.status == "PENDING":
            raise ValidationError(
                "You already have a pending creator application undergoing review.",
                code="APPLICATION_PENDING",
            )

        return await self.studio_repo.create_application(
            user_id=user_id,
            artist_name=artist_name,
            bio=bio,
            genres=genres,
            portfolio_url=portfolio_url,
        )

    async def get_my_application(
        self,
        user_id: uuid.UUID,
    ) -> Optional[CreatorApplication]:
        """Gets user's latest creator application."""
        return await self.studio_repo.get_application_by_user(user_id)

    async def create_content_report(
        self,
        reporter_id: uuid.UUID,
        entity_type: str,
        entity_id: uuid.UUID,
        reason: str,
        description: Optional[str] = None,
    ) -> ContentReport:
        """Files a content violation report."""
        report = ContentReport(
            id=uuid.uuid4(),
            reporter_id=reporter_id,
            entity_type=entity_type,
            entity_id=entity_id,
            reason=reason,
            description=description,
            status="PENDING",
        )
        self.studio_repo.session.add(report)
        await self.studio_repo.session.commit()
        await self.studio_repo.session.refresh(report)
        return report
