import io
import logging
import os
import uuid
from datetime import datetime
from typing import Any, Dict, List, Optional, Tuple

from PIL import Image

from app.core.config import get_settings
from app.core.errors import BadRequestError, ForbiddenError, NotFoundError, ValidationError
from app.db.models.admin import ContentReport, CreatorApplication
from app.db.models.creator import Creator
from app.repositories.creator_studio_repository import CreatorStudioRepository
from app.schemas.creator_studio import (
    BulkTrackActionResult,
    CreatorAnalyticsResponse,
    CreatorDashboardStats,
    CreatorStudioProfile,
    CreatorTrackDetail,
    CreatorTrackItem,
)
from app.utils.storage import BaseStorageService, S3StorageService

logger = logging.getLogger("hums.creator_studio")
settings = get_settings()

ALLOWED_IMAGE_MIME_TYPES = {"image/jpeg", "image/png", "image/webp"}
ALLOWED_IMAGE_FORMATS = {"JPEG", "PNG", "WEBP"}
MIN_IMAGE_DIMENSION = 200
MAX_IMAGE_DIMENSION = 4000


class CreatorStudioService:
    """Business logic for Creator Studio content management, analytics, and applications."""

    def __init__(
        self,
        studio_repo: CreatorStudioRepository,
        storage_service: Optional[BaseStorageService] = None,
    ):
        self.studio_repo = studio_repo
        self.storage_service = storage_service or S3StorageService()

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
        is_published: Optional[bool] = None,
        genre: Optional[str] = None,
        search: Optional[str] = None,
        date_from: Optional[datetime] = None,
        date_to: Optional[datetime] = None,
        sort_by: str = "created_at",
        sort_order: str = "desc",
    ) -> Tuple[List[CreatorTrackItem], int]:
        """Lists tracks owned by the authenticated creator with multi-field filtering and sorting."""
        items, total = await self.studio_repo.list_tracks(
            user_id=user_id,
            page=page,
            size=size,
            status=status,
            is_published=is_published,
            genre=genre,
            search=search,
            date_from=date_from,
            date_to=date_to,
            sort_by=sort_by,
            sort_order=sort_order,
        )
        return [CreatorTrackItem.model_validate(t) for t in items], total

    async def get_track_detail(
        self,
        user_id: uuid.UUID,
        track_id: uuid.UUID,
    ) -> CreatorTrackDetail:
        """Fetches comprehensive track detail with renditions and processing history."""
        track_dict = await self.studio_repo.get_track_detail(user_id=user_id, track_id=track_id)
        if not track_dict:
            raise NotFoundError(
                f"Track {track_id} not found or you do not have permission to view it.",
                code="TRACK_NOT_FOUND_OR_FORBIDDEN",
            )
        return CreatorTrackDetail.model_validate(track_dict)

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

    async def set_publishing(
        self,
        user_id: uuid.UUID,
        track_id: uuid.UUID,
        is_published: bool,
    ) -> CreatorTrackItem:
        """Publishes or unpublishes a creator track with readiness validation."""
        track = await self.studio_repo.get_track(user_id, track_id)
        if not track:
            raise NotFoundError(
                f"Track {track_id} not found or you do not have permission to modify it.",
                code="TRACK_NOT_FOUND_OR_FORBIDDEN",
            )

        if is_published and track.status != "READY":
            raise ValidationError(
                f"Cannot publish track with processing status '{track.status}'. Only tracks in READY state can be published.",
                code="TRACK_NOT_READY_FOR_PUBLISHING",
            )

        updated_track = await self.studio_repo.set_publishing(user_id, track_id, is_published)

        if is_published:
            try:
                from app.schemas.notification import NotificationType
                from app.services.notification_service import NotificationService
                notif_service = NotificationService()
                await notif_service.notify_user(
                    user_id=user_id,
                    notification_type=NotificationType.TRACK_PUBLISHED.value,
                    title="Track Published!",
                    body=f"Your track '{updated_track.title}' is now live on Hums.",
                    data={"track_id": str(updated_track.id), "title": updated_track.title},
                    idempotency_key=f"track_pub_{updated_track.id}",
                )
            except Exception as notif_err:
                logger.warning(f"Could not dispatch notification for track {track_id}: {notif_err}")

        return CreatorTrackItem.model_validate(updated_track)

    async def upload_artwork(
        self,
        user_id: uuid.UUID,
        track_id: uuid.UUID,
        file_bytes: bytes,
        filename: str,
        content_type: str,
    ) -> Dict[str, str]:
        """Validates and uploads cover artwork for an owned track."""
        track = await self.studio_repo.get_track(user_id, track_id)
        if not track:
            raise NotFoundError(
                f"Track {track_id} not found or you do not have permission to modify it.",
                code="TRACK_NOT_FOUND_OR_FORBIDDEN",
            )

        clean_content_type = (content_type or "").lower().strip()
        if clean_content_type not in ALLOWED_IMAGE_MIME_TYPES:
            raise BadRequestError(
                "Unsupported image type. Allowed formats: JPEG, PNG, WebP.",
                code="UNSUPPORTED_IMAGE_TYPE",
            )

        max_bytes = settings.MAX_AVATAR_SIZE_MB * 1024 * 1024
        if len(file_bytes) > max_bytes:
            raise BadRequestError(
                f"Cover image exceeds the {settings.MAX_AVATAR_SIZE_MB}MB size limit.",
                code="IMAGE_TOO_LARGE",
            )
        if len(file_bytes) < 100:
            raise BadRequestError("Cover image is empty or too small.", code="INVALID_IMAGE")

        # Verify image using PIL
        try:
            image_stream = io.BytesIO(file_bytes)
            img = Image.open(image_stream)
            img.verify()

            image_stream.seek(0)
            img = Image.open(image_stream)
            img_format = (img.format or "").upper()

            if img_format not in ALLOWED_IMAGE_FORMATS:
                raise BadRequestError(
                    "Unsupported image format. Allowed formats: JPEG, PNG, WebP.",
                    code="UNSUPPORTED_IMAGE_TYPE",
                )

            width, height = img.size
            if width < MIN_IMAGE_DIMENSION or height < MIN_IMAGE_DIMENSION:
                raise BadRequestError(
                    f"Image is too small ({width}x{height}). Minimum dimensions are {MIN_IMAGE_DIMENSION}x{MIN_IMAGE_DIMENSION}.",
                    code="IMAGE_TOO_SMALL",
                )
            if width > MAX_IMAGE_DIMENSION or height > MAX_IMAGE_DIMENSION:
                raise BadRequestError(
                    f"Image is too large ({width}x{height}). Maximum dimensions are {MAX_IMAGE_DIMENSION}x{MAX_IMAGE_DIMENSION}.",
                    code="IMAGE_TOO_LARGE",
                )
        except BadRequestError:
            raise
        except Exception as exc:
            logger.error(f"Image verification failed: {exc}")
            raise BadRequestError("Invalid or corrupted image file.", code="INVALID_IMAGE")

        ext = "jpg" if img_format == "JPEG" else img_format.lower()
        cover_image_key = f"artwork/tracks/{track_id}/{uuid.uuid4()}.{ext}"

        # Upload to object storage
        await self.storage_service.upload_file(
            file_bytes=file_bytes,
            destination_key=cover_image_key,
            content_type=clean_content_type,
        )

        await self.studio_repo.update_artwork(user_id, track_id, cover_image_key)

        return {
            "track_id": str(track_id),
            "cover_image_key": cover_image_key,
            "cover_image_url": f"{settings.CDN_BASE_URL}/{cover_image_key}",
        }

    async def bulk_action(
        self,
        user_id: uuid.UUID,
        action: str,
        track_ids: List[uuid.UUID],
        data: Optional[Dict[str, Any]] = None,
    ) -> BulkTrackActionResult:
        """Executes bulk operations on creator-owned tracks."""
        if not track_ids or len(track_ids) > 50:
            raise BadRequestError(
                "Batch size must be between 1 and 50 tracks.",
                code="INVALID_BATCH_SIZE",
            )

        res = await self.studio_repo.bulk_action(
            user_id=user_id,
            action=action,
            track_ids=track_ids,
            data=data,
        )
        return BulkTrackActionResult.model_validate(res)

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

        track.status = "PROCESSING"
        await self.studio_repo.session.commit()

        # Trigger worker
        try:
            from app.workers.audio_tasks import process_audio_track
            process_audio_track.delay(str(track_id))
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
