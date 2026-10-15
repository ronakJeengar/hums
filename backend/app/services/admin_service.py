import io
import logging
import uuid
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional, Tuple

from PIL import Image

from app.core.config import get_settings
from app.core.errors import BadRequestError, NotFoundError, ValidationError
from app.db.models.admin import AdminAuditLog, ContentReport, CreatorApplication
from app.db.models.audio import Track
from app.db.models.user import User
from app.repositories.admin_repository import AdminRepository
from app.schemas.admin import AdminDashboardStats, SystemHealthStatus
from app.utils.storage import BaseStorageService, S3StorageService

logger = logging.getLogger("hums.admin")
settings = get_settings()

ALLOWED_IMAGE_MIME_TYPES = {"image/jpeg", "image/png", "image/webp"}
ALLOWED_IMAGE_FORMATS = {"JPEG", "PNG", "WEBP"}
MIN_IMAGE_DIMENSION = 200
MAX_IMAGE_DIMENSION = 4000


class AdminService:
    """Service orchestrating administrative operations, moderation, health, and audit logs."""

    def __init__(
        self,
        admin_repo: AdminRepository,
        storage_service: Optional[BaseStorageService] = None,
    ):
        self.admin_repo = admin_repo
        self.storage_service = storage_service or S3StorageService()

    async def get_dashboard_stats(self) -> AdminDashboardStats:
        """Retrieves verified dashboard metrics and KPIs."""
        raw_stats = await self.admin_repo.get_dashboard_stats()
        return AdminDashboardStats(
            total_users=raw_stats["total_users"],
            active_users_30d=raw_stats["active_users_30d"],
            total_creators=raw_stats["total_creators"],
            published_tracks=raw_stats["published_tracks"],
            failed_uploads=raw_stats["failed_uploads"],
            pending_applications=raw_stats["pending_applications"],
            pending_reports=raw_stats["pending_reports"],
            subscriptions_summary=raw_stats["subscriptions_summary"],
            recent_activity=raw_stats["recent_activity"],
        )

    async def list_users(
        self,
        page: int = 1,
        size: int = 20,
        search: Optional[str] = None,
        role: Optional[str] = None,
        status: Optional[str] = None,
    ) -> Tuple[List[Dict[str, Any]], int]:
        """Lists platform users with bounded pagination and filters."""
        return await self.admin_repo.list_users(
            page=page,
            size=size,
            search=search,
            role=role,
            status=status,
        )

    async def get_user_detail(self, user_id: uuid.UUID) -> Dict[str, Any]:
        """Fetches full administrative user profile."""
        user = await self.admin_repo.get_user_detail(user_id)
        if not user:
            raise NotFoundError(f"User {user_id} not found", code="USER_NOT_FOUND")
        return user

    async def update_user_status(
        self,
        actor: User,
        user_id: uuid.UUID,
        is_active: bool,
        reason: Optional[str] = None,
        ip_address: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Suspends or reactivates an account with reasoned audit logging."""
        if actor.id == user_id and not is_active:
            raise ValidationError("Administrators cannot suspend their own account.", code="CANNOT_SUSPEND_SELF")

        updated_user = await self.admin_repo.update_user_status(
            user_id=user_id,
            is_active=is_active,
            reason=reason,
        )
        if not updated_user:
            raise NotFoundError(f"User {user_id} not found", code="USER_NOT_FOUND")

        action = "USER_ACTIVATE" if is_active else "USER_SUSPEND"
        await self.admin_repo.log_audit_action(
            actor_id=actor.id,
            actor_email=actor.email,
            action=action,
            target_type="user",
            target_id=str(user_id),
            details={"is_active": is_active, "reason": reason},
            reason=reason,
            ip_address=ip_address,
        )

        return await self.admin_repo.get_user_detail(user_id)

    async def update_user_role(
        self,
        actor: User,
        user_id: uuid.UUID,
        role: str,
        reason: Optional[str] = None,
        ip_address: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Changes user platform role."""
        if actor.id == user_id and role != "admin":
            raise ValidationError("Administrators cannot remove their own administrator role.", code="CANNOT_DEMOTE_SELF")

        updated_user = await self.admin_repo.update_user_role(user_id=user_id, role=role)
        if not updated_user:
            raise NotFoundError(f"User {user_id} not found", code="USER_NOT_FOUND")

        await self.admin_repo.log_audit_action(
            actor_id=actor.id,
            actor_email=actor.email,
            action="USER_ROLE_CHANGE",
            target_type="user",
            target_id=str(user_id),
            details={"new_role": role, "reason": reason},
            reason=reason,
            ip_address=ip_address,
        )

        return await self.admin_repo.get_user_detail(user_id)

    async def list_creators(
        self,
        page: int = 1,
        size: int = 20,
        search: Optional[str] = None,
    ) -> Tuple[List[Dict[str, Any]], int]:
        """Lists creators."""
        return await self.admin_repo.list_creators(page=page, size=size, search=search)

    async def verify_creator(
        self,
        actor: User,
        creator_id: uuid.UUID,
        is_verified: bool,
        reason: Optional[str] = None,
        ip_address: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Toggles creator verified badge with audit log."""
        creator = await self.admin_repo.verify_creator(creator_id, is_verified)
        if not creator:
            raise NotFoundError(f"Creator {creator_id} not found", code="CREATOR_NOT_FOUND")

        await self.admin_repo.log_audit_action(
            actor_id=actor.id,
            actor_email=actor.email,
            action="CREATOR_VERIFY" if is_verified else "CREATOR_UNVERIFY",
            target_type="creator",
            target_id=str(creator_id),
            details={"is_verified": is_verified, "reason": reason},
            reason=reason,
            ip_address=ip_address,
        )

        return {
            "id": creator.id,
            "user_id": creator.user_id,
            "name": creator.name,
            "username": creator.username,
            "bio": creator.bio,
            "avatar_url": creator.avatar_url,
            "cover_image_url": creator.cover_image_url,
            "is_verified": creator.is_verified,
            "followers_count": creator.followers_count,
            "created_at": creator.created_at,
        }

    async def list_creator_applications(
        self,
        page: int = 1,
        size: int = 20,
        status: Optional[str] = None,
    ) -> Tuple[List[CreatorApplication], int]:
        """Lists creator applications."""
        return await self.admin_repo.list_creator_applications(
            page=page, size=size, status=status
        )

    async def review_creator_application(
        self,
        actor: User,
        app_id: uuid.UUID,
        status: str,
        review_notes: Optional[str] = None,
        ip_address: Optional[str] = None,
    ) -> CreatorApplication:
        """Approves or rejects a creator application."""
        app = await self.admin_repo.review_creator_application(
            app_id=app_id,
            status=status,
            reviewer_id=actor.id,
            review_notes=review_notes,
        )
        if not app:
            raise NotFoundError(f"Application {app_id} not found", code="APPLICATION_NOT_FOUND")

        await self.admin_repo.log_audit_action(
            actor_id=actor.id,
            actor_email=actor.email,
            action=f"CREATOR_APP_{status}",
            target_type="creator_application",
            target_id=str(app_id),
            details={"status": status, "review_notes": review_notes},
            reason=review_notes,
            ip_address=ip_address,
        )
        return app

    async def list_tracks(
        self,
        page: int = 1,
        size: int = 20,
        search: Optional[str] = None,
        status: Optional[str] = None,
        is_published: Optional[bool] = None,
        genre: Optional[str] = None,
        date_from: Optional[datetime] = None,
        date_to: Optional[datetime] = None,
        sort_by: str = "created_at",
        sort_order: str = "desc",
    ) -> Tuple[List[Dict[str, Any]], int]:
        """Lists tracks across catalog with filters and sorting."""
        return await self.admin_repo.list_tracks(
            page=page,
            size=size,
            search=search,
            status=status,
            is_published=is_published,
            genre=genre,
            date_from=date_from,
            date_to=date_to,
            sort_by=sort_by,
            sort_order=sort_order,
        )

    async def get_track_detail(self, track_id: uuid.UUID) -> Dict[str, Any]:
        """Fetches detailed track data."""
        track = await self.admin_repo.get_track_detail(track_id)
        if not track:
            raise NotFoundError(f"Track {track_id} not found", code="TRACK_NOT_FOUND")
        return track

    async def moderate_track(
        self,
        actor: User,
        track_id: uuid.UUID,
        status: str,
        reason: str,
        ip_address: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Moderates track status with audit log."""
        track = await self.admin_repo.update_track_status(track_id, status)
        if not track:
            raise NotFoundError(f"Track {track_id} not found", code="TRACK_NOT_FOUND")

        await self.admin_repo.log_audit_action(
            actor_id=actor.id,
            actor_email=actor.email,
            action=f"TRACK_MODERATE_{status}",
            target_type="track",
            target_id=str(track_id),
            details={"new_status": status, "reason": reason},
            reason=reason,
            ip_address=ip_address,
        )
        return await self.get_track_detail(track_id)

    async def retry_track_processing(
        self,
        actor: User,
        track_id: uuid.UUID,
        ip_address: Optional[str] = None,
    ) -> Dict[str, str]:
        """Triggers asynchronous Celery reprocessing for a failed track."""
        track = await self.admin_repo.get_track_detail(track_id)
        if not track:
            raise NotFoundError(f"Track {track_id} not found", code="TRACK_NOT_FOUND")

        # Set status back to PROCESSING
        await self.admin_repo.update_track_status(track_id, "PROCESSING")

        # Dispatch Celery worker job safely
        try:
            from app.workers.audio_tasks import process_audio_track
            process_audio_track.delay(str(track_id))
        except Exception:
            pass

        await self.admin_repo.log_audit_action(
            actor_id=actor.id,
            actor_email=actor.email,
            action="TRACK_RETRY_PROCESSING",
            target_type="track",
            target_id=str(track_id),
            reason="Administrator manual retry trigger",
            ip_address=ip_address,
        )
        return {"message": "Track processing retry queued successfully."}

    async def bulk_action(
        self,
        actor: User,
        action: str,
        track_ids: List[uuid.UUID],
        reason: str,
        status: Optional[str] = None,
        data: Optional[Dict[str, Any]] = None,
        ip_address: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Executes administrative bulk operations with per-item reporting and audit logs."""
        if not track_ids or len(track_ids) > 50:
            raise BadRequestError(
                "Batch size must be between 1 and 50 tracks.",
                code="INVALID_BATCH_SIZE",
            )

        return await self.admin_repo.bulk_action(
            actor_id=actor.id,
            actor_email=actor.email,
            action=action,
            track_ids=track_ids,
            reason=reason,
            status=status,
            data=data,
            ip_address=ip_address,
        )

    async def upload_artwork(
        self,
        actor: User,
        track_id: uuid.UUID,
        file_bytes: bytes,
        filename: str,
        content_type: str,
        ip_address: Optional[str] = None,
    ) -> Dict[str, str]:
        """Admin override: Validates and uploads cover artwork for any track."""
        track_dict = await self.admin_repo.get_track_detail(track_id)
        if not track_dict:
            raise NotFoundError(f"Track {track_id} not found", code="TRACK_NOT_FOUND")

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

        await self.storage_service.upload_file(
            file_bytes=file_bytes,
            destination_key=cover_image_key,
            content_type=clean_content_type,
        )

        # Update track in db
        track_obj = (
            await self.admin_repo.session.execute(
                select(Track).where(Track.id == track_id)
            )
        ).scalar_one_or_none()
        if track_obj:
            track_obj.cover_image_key = cover_image_key
            await self.admin_repo.session.commit()

        await self.admin_repo.log_audit_action(
            actor_id=actor.id,
            actor_email=actor.email,
            action="TRACK_UPDATE_ARTWORK",
            target_type="track",
            target_id=str(track_id),
            details={"cover_image_key": cover_image_key},
            reason="Administrator updated track cover artwork",
            ip_address=ip_address,
        )

        return {
            "track_id": str(track_id),
            "cover_image_key": cover_image_key,
            "cover_image_url": f"{settings.CDN_BASE_URL}/{cover_image_key}",
        }

    async def list_reports(
        self,
        page: int = 1,
        size: int = 20,
        status: Optional[str] = None,
        reason: Optional[str] = None,
        entity_type: Optional[str] = None,
    ) -> Tuple[List[ContentReport], int]:
        """Lists content reports."""
        return await self.admin_repo.list_reports(
            page=page, size=size, status=status, reason=reason, entity_type=entity_type
        )

    async def resolve_report(
        self,
        actor: User,
        report_id: uuid.UUID,
        status: str,
        resolution_notes: Optional[str] = None,
        action_taken: Optional[str] = None,
        ip_address: Optional[str] = None,
    ) -> ContentReport:
        """Resolves or dismisses a moderation report."""
        report = await self.admin_repo.resolve_report(
            report_id=report_id,
            status=status,
            moderator_id=actor.id,
            resolution_notes=resolution_notes,
            action_taken=action_taken,
        )
        if not report:
            raise NotFoundError(f"Report {report_id} not found", code="REPORT_NOT_FOUND")

        await self.admin_repo.log_audit_action(
            actor_id=actor.id,
            actor_email=actor.email,
            action=f"REPORT_{status}",
            target_type="report",
            target_id=str(report_id),
            details={"status": status, "action_taken": action_taken, "notes": resolution_notes},
            reason=resolution_notes,
            ip_address=ip_address,
        )
        return report

    async def list_audit_logs(
        self,
        page: int = 1,
        size: int = 20,
        action: Optional[str] = None,
        target_type: Optional[str] = None,
        search: Optional[str] = None,
    ) -> Tuple[List[AdminAuditLog], int]:
        """Lists audit logs."""
        return await self.admin_repo.list_audit_logs(
            page=page, size=size, action=action, target_type=target_type, search=search
        )

    async def list_processing_jobs(
        self,
        page: int = 1,
        size: int = 20,
        status: Optional[str] = None,
    ) -> Tuple[List[Dict[str, Any]], int]:
        """Lists processing jobs."""
        return await self.admin_repo.list_processing_jobs(page=page, size=size, status=status)

    async def get_system_health(self) -> SystemHealthStatus:
        """Checks live connectivity for all backend dependencies."""
        from app.core.dependencies import check_celery_broker_health, check_redis_health, check_storage_health

        db_ok = True
        try:
            from sqlalchemy import text
            await self.admin_repo.session.execute(text("SELECT 1"))
        except Exception:
            db_ok = False

        redis_ok = await check_redis_health()
        celery_ok = await check_celery_broker_health()
        storage_ok = await check_storage_health()

        return SystemHealthStatus(
            database=db_ok,
            redis=redis_ok,
            celery_broker=celery_ok,
            storage=storage_ok,
            environment=settings.APP_ENV,
            timestamp=datetime.now(timezone.utc),
        )
