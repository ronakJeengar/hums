import uuid
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, List, Optional, Tuple
from sqlalchemy import and_, asc, desc, func, or_, select, update
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.db.models.admin import AdminAuditLog, ContentReport, CreatorApplication
from app.db.models.audio import AudioFile, AudioRendition, ProcessingJob, Track
from app.db.models.creator import Creator
from app.db.models.playback import PlaybackEvent
from app.db.models.subscription import SubscriptionPlan, UserSubscription
from app.db.models.user import User


class AdminRepository:
    """Repository for administrative data access, moderation, and platform operations."""

    def __init__(self, session: AsyncSession):
        self.session = session

    async def get_dashboard_stats(self) -> Dict[str, Any]:
        """Aggregates platform KPIs and administrative summaries."""
        now = datetime.now(timezone.utc)
        thirty_days_ago = now - timedelta(days=30)

        # 1. User stats
        total_users = (
            await self.session.execute(select(func.count()).select_from(User))
        ).scalar() or 0

        active_users_30d = (
            await self.session.execute(
                select(func.count())
                .select_from(User)
                .where(User.last_login_at >= thirty_days_ago)
            )
        ).scalar() or 0

        # 2. Creators & tracks
        total_creators = (
            await self.session.execute(select(func.count()).select_from(Creator))
        ).scalar() or 0

        published_tracks = (
            await self.session.execute(
                select(func.count())
                .select_from(Track)
                .where(Track.status == "READY")
            )
        ).scalar() or 0

        failed_uploads = (
            await self.session.execute(
                select(func.count())
                .select_from(Track)
                .where(Track.status == "FAILED")
            )
        ).scalar() or 0

        # 3. Queues
        pending_applications = (
            await self.session.execute(
                select(func.count())
                .select_from(CreatorApplication)
                .where(CreatorApplication.status == "PENDING")
            )
        ).scalar() or 0

        pending_reports = (
            await self.session.execute(
                select(func.count())
                .select_from(ContentReport)
                .where(ContentReport.status == "PENDING")
            )
        ).scalar() or 0

        # 4. Subscriptions breakdown
        sub_rows = (
            await self.session.execute(
                select(SubscriptionPlan.code, func.count())
                .select_from(UserSubscription)
                .join(SubscriptionPlan, UserSubscription.plan_id == SubscriptionPlan.id)
                .where(UserSubscription.status == "ACTIVE")
                .group_by(SubscriptionPlan.code)
            )
        ).all()
        sub_summary: Dict[str, int] = {"total_active": 0}
        for plan_code, count in sub_rows:
            sub_summary[plan_code.lower()] = count
            sub_summary["total_active"] += count

        # 5. Recent audit logs
        recent_logs_query = (
            select(AdminAuditLog)
            .order_by(desc(AdminAuditLog.created_at))
            .limit(10)
        )
        recent_logs = (await self.session.execute(recent_logs_query)).scalars().all()

        return {
            "total_users": total_users,
            "active_users_30d": active_users_30d,
            "total_creators": total_creators,
            "published_tracks": published_tracks,
            "failed_uploads": failed_uploads,
            "pending_applications": pending_applications,
            "pending_reports": pending_reports,
            "subscriptions_summary": sub_summary,
            "recent_activity": recent_logs,
        }

    async def list_users(
        self,
        page: int = 1,
        size: int = 20,
        search: Optional[str] = None,
        role: Optional[str] = None,
        status: Optional[str] = None,
    ) -> Tuple[List[Dict[str, Any]], int]:
        """Search and list users with pagination and filters."""
        query = select(User).options(
            selectinload(User.creator_profile),
            selectinload(User.subscriptions),
        )

        if search:
            search_pattern = f"%{search.strip().lower()}%"
            query = query.where(
                or_(
                    func.lower(User.email).like(search_pattern),
                    func.lower(User.username).like(search_pattern),
                    func.lower(User.full_name).like(search_pattern),
                )
            )

        if role:
            query = query.where(User.role == role)

        if status == "active":
            query = query.where(User.is_active == True)
        elif status == "suspended":
            query = query.where(User.is_active == False)

        # Count total
        count_query = select(func.count()).select_from(query.subquery())
        total = (await self.session.execute(count_query)).scalar() or 0

        # Paginate
        offset = (page - 1) * size
        query = (
            query.options(
                selectinload(User.creator_profile),
                selectinload(User.subscriptions).selectinload(UserSubscription.plan),
            )
            .order_by(desc(User.created_at))
            .offset(offset)
            .limit(size)
        )
        users = (await self.session.execute(query)).scalars().all()

        # Batch track counts
        user_ids = [u.id for u in users]
        track_counts: Dict[uuid.UUID, int] = {}
        if user_ids:
            counts_res = (
                await self.session.execute(
                    select(Track.owner_id, func.count())
                    .where(Track.owner_id.in_(user_ids))
                    .group_by(Track.owner_id)
                )
            ).all()
            track_counts = {owner_id: count for owner_id, count in counts_res}

        result = []
        for u in users:
            # Determine active subscription tier
            active_sub = next(
                (s for s in u.subscriptions if s.status == "ACTIVE"),
                None,
            )
            sub_tier = (
                active_sub.plan.code
                if (active_sub and getattr(active_sub, "plan", None))
                else "FREE"
            )

            result.append({
                "id": u.id,
                "email": u.email,
                "username": u.username,
                "full_name": u.full_name,
                "role": getattr(u, "role", "listener"),
                "is_active": u.is_active,
                "is_verified": u.is_verified,
                "suspension_reason": getattr(u, "suspension_reason", None),
                "created_at": u.created_at,
                "last_login_at": u.last_login_at,
                "tracks_count": track_counts.get(u.id, 0),
                "has_creator_profile": u.creator_profile is not None,
                "subscription_tier": sub_tier,
            })

        return result, total

    async def get_user_detail(self, user_id: uuid.UUID) -> Optional[Dict[str, Any]]:
        """Retrieves comprehensive user information for admin inspection."""
        query = (
            select(User)
            .options(
                selectinload(User.creator_profile),
                selectinload(User.subscriptions).selectinload(UserSubscription.plan),
                selectinload(User.tracks),
            )
            .where(User.id == user_id)
        )
        user = (await self.session.execute(query)).scalar_one_or_none()
        if not user:
            return None

        active_sub = next(
            (s for s in user.subscriptions if s.status == "ACTIVE"),
            None,
        )
        sub_tier = (
            active_sub.plan.code
            if (active_sub and getattr(active_sub, "plan", None))
            else "FREE"
        )

        recent_tracks = [
            {
                "id": t.id,
                "title": t.title,
                "status": t.status,
                "created_at": t.created_at,
                "likes_count": t.likes_count,
            }
            for t in sorted(user.tracks, key=lambda x: x.created_at, reverse=True)[:5]
        ]

        return {
            "id": user.id,
            "email": user.email,
            "username": user.username,
            "full_name": user.full_name,
            "bio": user.bio,
            "avatar_url": user.avatar_url,
            "role": getattr(user, "role", "listener"),
            "is_active": user.is_active,
            "is_verified": user.is_verified,
            "suspension_reason": getattr(user, "suspension_reason", None),
            "created_at": user.created_at,
            "last_login_at": user.last_login_at,
            "tracks_count": len(user.tracks),
            "has_creator_profile": user.creator_profile is not None,
            "creator_id": user.creator_profile.id if user.creator_profile else None,
            "creator_name": user.creator_profile.name if user.creator_profile else None,
            "subscription_tier": sub_tier,
            "recent_tracks": recent_tracks,
        }

    async def update_user_status(
        self,
        user_id: uuid.UUID,
        is_active: bool,
        reason: Optional[str] = None,
    ) -> Optional[User]:
        """Suspends or reactivates a user account with reasoned audit fields."""
        user = (
            await self.session.execute(select(User).where(User.id == user_id))
        ).scalar_one_or_none()
        if not user:
            return None

        user.is_active = is_active
        if not is_active:
            user.suspension_reason = reason
            user.suspended_at = datetime.now(timezone.utc)
        else:
            user.suspension_reason = None
            user.suspended_at = None

        await self.session.commit()
        await self.session.refresh(user)
        return user

    async def update_user_role(
        self,
        user_id: uuid.UUID,
        role: str,
    ) -> Optional[User]:
        """Elevates or changes user role."""
        user = (
            await self.session.execute(select(User).where(User.id == user_id))
        ).scalar_one_or_none()
        if not user:
            return None

        user.role = role
        await self.session.commit()
        await self.session.refresh(user)
        return user

    async def list_creators(
        self,
        page: int = 1,
        size: int = 20,
        search: Optional[str] = None,
    ) -> Tuple[List[Dict[str, Any]], int]:
        """Lists creators with linked user and stats."""
        query = select(Creator).options(selectinload(Creator.user))

        if search:
            search_pat = f"%{search.strip().lower()}%"
            query = query.where(
                or_(
                    func.lower(Creator.name).like(search_pat),
                    func.lower(Creator.username).like(search_pat),
                )
            )

        count_query = select(func.count()).select_from(query.subquery())
        total = (await self.session.execute(count_query)).scalar() or 0

        offset = (page - 1) * size
        query = query.order_by(desc(Creator.created_at)).offset(offset).limit(size)
        creators = (await self.session.execute(query)).scalars().all()

        # Batch track counts
        creator_ids = [c.id for c in creators]
        track_counts: Dict[uuid.UUID, int] = {}
        if creator_ids:
            counts_res = (
                await self.session.execute(
                    select(Track.creator_id, func.count())
                    .where(Track.creator_id.in_(creator_ids))
                    .group_by(Track.creator_id)
                )
            ).all()
            track_counts = {cid: count for cid, count in counts_res}

        result = [
            {
                "id": c.id,
                "user_id": c.user_id,
                "user_email": c.user.email if c.user else None,
                "name": c.name,
                "username": c.username,
                "bio": c.bio,
                "avatar_url": c.avatar_url,
                "cover_image_url": c.cover_image_url,
                "is_verified": c.is_verified,
                "followers_count": c.followers_count,
                "tracks_count": track_counts.get(c.id, 0),
                "created_at": c.created_at,
            }
            for c in creators
        ]
        return result, total

    async def verify_creator(
        self,
        creator_id: uuid.UUID,
        is_verified: bool,
    ) -> Optional[Creator]:
        """Toggles creator verification status."""
        creator = (
            await self.session.execute(select(Creator).where(Creator.id == creator_id))
        ).scalar_one_or_none()
        if not creator:
            return None

        creator.is_verified = is_verified
        await self.session.commit()
        await self.session.refresh(creator)
        return creator

    async def list_creator_applications(
        self,
        page: int = 1,
        size: int = 20,
        status: Optional[str] = None,
    ) -> Tuple[List[CreatorApplication], int]:
        """Lists submitted creator applications."""
        query = select(CreatorApplication).options(selectinload(CreatorApplication.user))
        if status:
            query = query.where(CreatorApplication.status == status)

        count_query = select(func.count()).select_from(query.subquery())
        total = (await self.session.execute(count_query)).scalar() or 0

        offset = (page - 1) * size
        query = query.order_by(desc(CreatorApplication.created_at)).offset(offset).limit(size)
        items = (await self.session.execute(query)).scalars().all()
        return list(items), total

    async def review_creator_application(
        self,
        app_id: uuid.UUID,
        status: str,
        reviewer_id: uuid.UUID,
        review_notes: Optional[str] = None,
    ) -> Optional[CreatorApplication]:
        """Approves or rejects a creator application."""
        app = (
            await self.session.execute(
                select(CreatorApplication)
                .options(selectinload(CreatorApplication.user))
                .where(CreatorApplication.id == app_id)
            )
        ).scalar_one_or_none()
        if not app:
            return None

        now = datetime.now(timezone.utc)
        app.status = status
        app.reviewer_id = reviewer_id
        app.review_notes = review_notes
        app.reviewed_at = now

        if status == "APPROVED" and app.user:
            # Elevate user to creator role
            app.user.role = "creator"
            # Ensure creator profile exists
            existing_creator = (
                await self.session.execute(
                    select(Creator).where(Creator.user_id == app.user_id)
                )
            ).scalar_one_or_none()
            if not existing_creator:
                new_creator = Creator(
                    id=uuid.uuid4(),
                    user_id=app.user_id,
                    name=app.artist_name,
                    bio=app.bio,
                    is_verified=True,
                    followers_count=0,
                )
                self.session.add(new_creator)

        await self.session.commit()
        await self.session.refresh(app)
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
        """Lists tracks with pagination, status/publishing filters, and sorting."""
        query = select(Track).options(selectinload(Track.owner))

        if search:
            search_pat = f"%{search.strip().lower()}%"
            query = query.where(
                or_(
                    func.lower(Track.title).like(search_pat),
                    func.lower(Track.artist_name).like(search_pat),
                    func.lower(Track.album_name).like(search_pat),
                )
            )

        if status:
            query = query.where(Track.status == status)

        if is_published is not None:
            query = query.where(Track.is_published.is_(is_published))

        if genre:
            query = query.where(func.lower(Track.genre) == genre.strip().lower())

        if date_from:
            query = query.where(Track.created_at >= date_from)

        if date_to:
            query = query.where(Track.created_at <= date_to)

        count_query = select(func.count()).select_from(query.subquery())
        total = (await self.session.execute(count_query)).scalar() or 0

        # Sorting logic
        sort_col = Track.created_at
        if sort_by == "title":
            sort_col = Track.title
        elif sort_by == "duration_seconds":
            sort_col = Track.duration_seconds
        elif sort_by == "likes_count":
            sort_col = Track.likes_count

        order_expr = desc(sort_col) if sort_order.lower() == "desc" else asc(sort_col)
        query = query.order_by(order_expr)

        offset = (page - 1) * size
        query = query.offset(offset).limit(size)
        tracks = (await self.session.execute(query)).scalars().all()

        # Batch play counts from PlaybackEvent
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
                "is_published": t.is_published,
                "cover_image_key": t.cover_image_key,
                "owner_id": t.owner_id,
                "owner_email": t.owner.email if t.owner else None,
                "created_at": t.created_at,
                "likes_count": t.likes_count,
                "play_count": play_counts.get(t.id, 0),
            }
            for t in tracks
        ]
        return result, total

    async def get_track_detail(self, track_id: uuid.UUID) -> Optional[Dict[str, Any]]:
        """Fetches track with renditions, processing history, and audit logs."""
        query = (
            select(Track)
            .options(
                selectinload(Track.owner),
                selectinload(Track.renditions),
                selectinload(Track.processing_jobs),
            )
            .where(Track.id == track_id)
        )
        t = (await self.session.execute(query)).scalar_one_or_none()
        if not t:
            return None

        # Play count
        play_count = (
            await self.session.execute(
                select(func.count())
                .select_from(PlaybackEvent)
                .where(
                    PlaybackEvent.track_id == t.id,
                    PlaybackEvent.event_type.in_(["start", "complete"]),
                )
            )
        ).scalar() or 0

        renditions = [
            {
                "id": r.id,
                "format": r.format,
                "codec": r.codec,
                "bitrate_kbps": r.bitrate_kbps,
                "file_size_bytes": r.file_size_bytes,
                "storage_key": r.storage_key,
            }
            for r in t.renditions
        ]

        processing_jobs = [
            {
                "id": j.id,
                "job_type": j.job_type,
                "status": j.status,
                "attempts": j.attempts,
                "error_message": j.error_message,
                "created_at": j.created_at,
                "updated_at": j.updated_at,
            }
            for j in t.processing_jobs
        ]

        # Audit logs for this track
        logs_query = (
            select(AdminAuditLog)
            .where(
                AdminAuditLog.target_type == "track",
                AdminAuditLog.target_id == str(track_id),
            )
            .order_by(desc(AdminAuditLog.created_at))
            .limit(20)
        )
        logs = (await self.session.execute(logs_query)).scalars().all()
        audit_logs = [
            {
                "id": l.id,
                "actor_id": l.actor_id,
                "actor_email": l.actor_email,
                "action": l.action,
                "reason": l.reason,
                "details": l.details,
                "created_at": l.created_at,
            }
            for l in logs
        ]

        return {
            "id": t.id,
            "title": t.title,
            "artist_name": t.artist_name,
            "album_name": t.album_name,
            "genre": t.genre,
            "description": t.description,
            "duration_seconds": t.duration_seconds,
            "status": t.status,
            "is_published": t.is_published,
            "cover_image_key": t.cover_image_key,
            "waveform_key": t.waveform_key,
            "owner_id": t.owner_id,
            "owner_email": t.owner.email if t.owner else None,
            "created_at": t.created_at,
            "likes_count": t.likes_count,
            "play_count": play_count,
            "renditions": renditions,
            "processing_jobs": processing_jobs,
            "audit_logs": audit_logs,
        }

    async def bulk_action(
        self,
        actor_id: uuid.UUID,
        actor_email: str,
        action: str,
        track_ids: List[uuid.UUID],
        reason: str,
        status: Optional[str] = None,
        data: Optional[Dict[str, Any]] = None,
        ip_address: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Executes administrative bulk track actions with per-item reporting and audit logging."""
        results = []
        succeeded = 0
        failed = 0

        tracks_res = await self.session.execute(
            select(Track).where(Track.id.in_(track_ids))
        )
        tracks_by_id = {t.id: t for t in tracks_res.scalars().all()}

        for tid in track_ids:
            track = tracks_by_id.get(tid)
            if not track:
                failed += 1
                results.append({
                    "track_id": tid,
                    "title": None,
                    "status": "failed",
                    "error": "Track not found.",
                })
                continue

            if action == "moderate":
                new_status = status or "MODERATED"
                track.status = new_status
                succeeded += 1
                results.append({
                    "track_id": tid,
                    "title": track.title,
                    "status": "success",
                    "message": f"Track status updated to {new_status}.",
                })

            elif action == "publish":
                track.is_published = True
                succeeded += 1
                results.append({
                    "track_id": tid,
                    "title": track.title,
                    "status": "success",
                    "message": "Track published.",
                })

            elif action == "unpublish":
                track.is_published = False
                succeeded += 1
                results.append({
                    "track_id": tid,
                    "title": track.title,
                    "status": "success",
                    "message": "Track unpublished.",
                })

            elif action == "retry":
                track.status = "PROCESSING"
                try:
                    from app.workers.audio_tasks import process_audio_track
                    process_audio_track.delay(str(track.id))
                except Exception:
                    pass
                succeeded += 1
                results.append({
                    "track_id": tid,
                    "title": track.title,
                    "status": "success",
                    "message": "Processing retry enqueued.",
                })

            elif action == "update_metadata":
                if data:
                    if "genre" in data and data["genre"]:
                        track.genre = data["genre"].strip()
                    if "album_name" in data and data["album_name"]:
                        track.album_name = data["album_name"].strip()
                succeeded += 1
                results.append({
                    "track_id": tid,
                    "title": track.title,
                    "status": "success",
                    "message": "Metadata updated.",
                })

        # Record audit log
        log = AdminAuditLog(
            id=uuid.uuid4(),
            actor_id=actor_id,
            actor_email=actor_email,
            action=f"BULK_TRACK_{action.upper()}",
            target_type="track_bulk",
            target_id=",".join(str(tid) for tid in track_ids[:10]),
            details={
                "action": action,
                "target_count": len(track_ids),
                "succeeded": succeeded,
                "failed": failed,
                "reason": reason,
                "status": status,
            },
            reason=reason,
            ip_address=ip_address,
        )
        self.session.add(log)
        await self.session.commit()

        return {
            "action": action,
            "total": len(track_ids),
            "succeeded": succeeded,
            "failed": failed,
            "results": results,
        }

    async def update_track_status(
        self,
        track_id: uuid.UUID,
        status: str,
    ) -> Optional[Track]:
        """Moderates or updates track status."""
        track = (
            await self.session.execute(select(Track).where(Track.id == track_id))
        ).scalar_one_or_none()
        if not track:
            return None

        track.status = status
        await self.session.commit()
        await self.session.refresh(track)
        return track

    async def list_reports(
        self,
        page: int = 1,
        size: int = 20,
        status: Optional[str] = None,
        reason: Optional[str] = None,
        entity_type: Optional[str] = None,
    ) -> Tuple[List[ContentReport], int]:
        """Lists content reports queue."""
        query = select(ContentReport).options(selectinload(ContentReport.reporter))

        if status:
            query = query.where(ContentReport.status == status)
        if reason:
            query = query.where(ContentReport.reason == reason)
        if entity_type:
            query = query.where(ContentReport.entity_type == entity_type)

        count_query = select(func.count()).select_from(query.subquery())
        total = (await self.session.execute(count_query)).scalar() or 0

        offset = (page - 1) * size
        query = query.order_by(desc(ContentReport.created_at)).offset(offset).limit(size)
        items = (await self.session.execute(query)).scalars().all()
        return list(items), total

    async def resolve_report(
        self,
        report_id: uuid.UUID,
        status: str,
        moderator_id: uuid.UUID,
        resolution_notes: Optional[str] = None,
        action_taken: Optional[str] = None,
    ) -> Optional[ContentReport]:
        """Resolves or dismisses a content report."""
        report = (
            await self.session.execute(
                select(ContentReport).where(ContentReport.id == report_id)
            )
        ).scalar_one_or_none()
        if not report:
            return None

        now = datetime.now(timezone.utc)
        report.status = status
        report.moderator_id = moderator_id
        report.resolution_notes = resolution_notes
        report.action_taken = action_taken
        report.resolved_at = now

        # If action taken is TRACK_REMOVED and entity is track, update track status to MODERATED
        if action_taken == "TRACK_REMOVED" and report.entity_type == "track":
            track = (
                await self.session.execute(
                    select(Track).where(Track.id == report.entity_id)
                )
            ).scalar_one_or_none()
            if track:
                track.status = "MODERATED"

        await self.session.commit()
        await self.session.refresh(report)
        return report

    async def list_audit_logs(
        self,
        page: int = 1,
        size: int = 20,
        action: Optional[str] = None,
        target_type: Optional[str] = None,
        search: Optional[str] = None,
    ) -> Tuple[List[AdminAuditLog], int]:
        """Lists administrative audit logs."""
        query = select(AdminAuditLog)

        if action:
            query = query.where(AdminAuditLog.action == action)
        if target_type:
            query = query.where(AdminAuditLog.target_type == target_type)
        if search:
            search_pat = f"%{search.strip().lower()}%"
            query = query.where(
                or_(
                    func.lower(AdminAuditLog.actor_email).like(search_pat),
                    func.lower(AdminAuditLog.reason).like(search_pat),
                    func.lower(AdminAuditLog.target_id).like(search_pat),
                )
            )

        count_query = select(func.count()).select_from(query.subquery())
        total = (await self.session.execute(count_query)).scalar() or 0

        offset = (page - 1) * size
        query = query.order_by(desc(AdminAuditLog.created_at)).offset(offset).limit(size)
        items = (await self.session.execute(query)).scalars().all()
        return list(items), total

    async def log_audit_action(
        self,
        actor_id: uuid.UUID,
        actor_email: str,
        action: str,
        target_type: str,
        target_id: str,
        details: Optional[Dict[str, Any]] = None,
        reason: Optional[str] = None,
        ip_address: Optional[str] = None,
    ) -> AdminAuditLog:
        """Records an immutable administrative action."""
        log = AdminAuditLog(
            id=uuid.uuid4(),
            actor_id=actor_id,
            actor_email=actor_email,
            action=action,
            target_type=target_type,
            target_id=str(target_id),
            details=details,
            reason=reason,
            ip_address=ip_address,
        )
        self.session.add(log)
        await self.session.commit()
        await self.session.refresh(log)
        return log

    async def list_processing_jobs(
        self,
        page: int = 1,
        size: int = 20,
        status: Optional[str] = None,
    ) -> Tuple[List[Dict[str, Any]], int]:
        """Lists media processing jobs with track titles."""
        query = select(ProcessingJob).options(selectinload(ProcessingJob.track))
        if status:
            query = query.where(ProcessingJob.status == status)

        count_query = select(func.count()).select_from(query.subquery())
        total = (await self.session.execute(count_query)).scalar() or 0

        offset = (page - 1) * size
        query = query.order_by(desc(ProcessingJob.created_at)).offset(offset).limit(size)
        jobs = (await self.session.execute(query)).scalars().all()

        result = [
            {
                "id": j.id,
                "track_id": j.track_id,
                "track_title": j.track.title if j.track else None,
                "job_type": j.job_type,
                "status": j.status,
                "attempts": j.attempts,
                "error_message": j.error_message,
                "created_at": j.created_at,
                "updated_at": j.updated_at,
            }
            for j in jobs
        ]
        return result, total
