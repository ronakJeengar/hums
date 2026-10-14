import uuid
from typing import Any, Dict, List, Optional
from fastapi import APIRouter, Depends, Query, Request, status

from app.core.dependencies import (
    get_admin_service,
    require_admin_role,
    require_moderator_or_admin_role,
)
from app.db.models.user import User
from app.schemas.admin import (
    AdminAuditLogItem,
    AdminCreatorItem,
    AdminDashboardStats,
    AdminTrackDetail,
    AdminTrackItem,
    AdminUserDetail,
    AdminUserItem,
    ContentReportItem,
    CreatorApplicationItem,
    ModerateTrackRequest,
    ProcessingJobItem,
    ResolveReportRequest,
    ReviewApplicationRequest,
    SystemHealthStatus,
    UpdateUserRoleRequest,
    UpdateUserStatusRequest,
    VerifyCreatorRequest,
)
from app.schemas.common import ApiResponse
from app.services.admin_service import AdminService

router = APIRouter(prefix="/admin", tags=["Admin Panel"])


# ============================================================================
# 1. Dashboard Overview
# ============================================================================

@router.get(
    "/dashboard",
    response_model=ApiResponse[AdminDashboardStats],
    status_code=status.HTTP_200_OK,
    summary="Get admin dashboard overview metrics",
)
async def get_dashboard_stats(
    current_admin: User = Depends(require_moderator_or_admin_role),
    admin_service: AdminService = Depends(get_admin_service),
) -> ApiResponse[AdminDashboardStats]:
    """Retrieves verified platform metrics, KPIs, and recent audit activity."""
    stats = await admin_service.get_dashboard_stats()
    return ApiResponse(data=stats)


# ============================================================================
# 2. User Management
# ============================================================================

@router.get(
    "/users",
    response_model=ApiResponse[Dict[str, Any]],
    status_code=status.HTTP_200_OK,
    summary="Search and list users with pagination and role filters",
)
async def list_users(
    page: int = Query(1, ge=1),
    size: int = Query(20, ge=1, le=100),
    search: Optional[str] = Query(None),
    role: Optional[str] = Query(None),
    status_filter: Optional[str] = Query(None, alias="status"),
    current_admin: User = Depends(require_moderator_or_admin_role),
    admin_service: AdminService = Depends(get_admin_service),
) -> ApiResponse[Dict[str, Any]]:
    """Paginated user directory with role and status filtering."""
    items, total = await admin_service.list_users(
        page=page,
        size=size,
        search=search,
        role=role,
        status=status_filter,
    )
    return ApiResponse(
        data={
            "items": [AdminUserItem.model_validate(u) for u in items],
            "total": total,
            "page": page,
            "size": size,
            "total_pages": (total + size - 1) // size if total > 0 else 1,
        }
    )


@router.get(
    "/users/{user_id}",
    response_model=ApiResponse[AdminUserDetail],
    status_code=status.HTTP_200_OK,
    summary="Get user details drawer for inspection",
)
async def get_user_detail(
    user_id: uuid.UUID,
    current_admin: User = Depends(require_moderator_or_admin_role),
    admin_service: AdminService = Depends(get_admin_service),
) -> ApiResponse[AdminUserDetail]:
    """Comprehensive user data including uploaded tracks summary and active subscription."""
    detail = await admin_service.get_user_detail(user_id)
    return ApiResponse(data=AdminUserDetail.model_validate(detail))


@router.patch(
    "/users/{user_id}/status",
    response_model=ApiResponse[AdminUserDetail],
    status_code=status.HTTP_200_OK,
    summary="Suspend or reactivate a user account",
)
async def update_user_status(
    user_id: uuid.UUID,
    payload: UpdateUserStatusRequest,
    request: Request,
    current_admin: User = Depends(require_admin_role),
    admin_service: AdminService = Depends(get_admin_service),
) -> ApiResponse[AdminUserDetail]:
    """Suspends or activates an account with audit logging. Admin-only."""
    client_ip = request.client.host if request.client else None
    result = await admin_service.update_user_status(
        actor=current_admin,
        user_id=user_id,
        is_active=payload.is_active,
        reason=payload.reason,
        ip_address=client_ip,
    )
    return ApiResponse(data=AdminUserDetail.model_validate(result))


@router.patch(
    "/users/{user_id}/role",
    response_model=ApiResponse[AdminUserDetail],
    status_code=status.HTTP_200_OK,
    summary="Update a user's platform role",
)
async def update_user_role(
    user_id: uuid.UUID,
    payload: UpdateUserRoleRequest,
    request: Request,
    current_admin: User = Depends(require_admin_role),
    admin_service: AdminService = Depends(get_admin_service),
) -> ApiResponse[AdminUserDetail]:
    """Changes user platform role. Admin-only."""
    client_ip = request.client.host if request.client else None
    result = await admin_service.update_user_role(
        actor=current_admin,
        user_id=user_id,
        role=payload.role,
        reason=payload.reason,
        ip_address=client_ip,
    )
    return ApiResponse(data=AdminUserDetail.model_validate(result))


# ============================================================================
# 3. Creator Management & Applications
# ============================================================================

@router.get(
    "/creators",
    response_model=ApiResponse[Dict[str, Any]],
    status_code=status.HTTP_200_OK,
    summary="List platform creators",
)
async def list_creators(
    page: int = Query(1, ge=1),
    size: int = Query(20, ge=1, le=100),
    search: Optional[str] = Query(None),
    current_admin: User = Depends(require_moderator_or_admin_role),
    admin_service: AdminService = Depends(get_admin_service),
) -> ApiResponse[Dict[str, Any]]:
    """Lists creators with follower counts and catalog track aggregates."""
    items, total = await admin_service.list_creators(page=page, size=size, search=search)
    return ApiResponse(
        data={
            "items": [AdminCreatorItem.model_validate(c) for c in items],
            "total": total,
            "page": page,
            "size": size,
            "total_pages": (total + size - 1) // size if total > 0 else 1,
        }
    )


@router.patch(
    "/creators/{creator_id}/verify",
    response_model=ApiResponse[AdminCreatorItem],
    status_code=status.HTTP_200_OK,
    summary="Toggle verified badge for creator",
)
async def verify_creator(
    creator_id: uuid.UUID,
    payload: VerifyCreatorRequest,
    request: Request,
    current_admin: User = Depends(require_admin_role),
    admin_service: AdminService = Depends(get_admin_service),
) -> ApiResponse[AdminCreatorItem]:
    """Toggles artist verified badge with audit log."""
    client_ip = request.client.host if request.client else None
    result = await admin_service.verify_creator(
        actor=current_admin,
        creator_id=creator_id,
        is_verified=payload.is_verified,
        reason=payload.reason,
        ip_address=client_ip,
    )
    return ApiResponse(data=AdminCreatorItem.model_validate(result))


@router.get(
    "/creator-applications",
    response_model=ApiResponse[Dict[str, Any]],
    status_code=status.HTTP_200_OK,
    summary="List creator applications queue",
)
async def list_creator_applications(
    page: int = Query(1, ge=1),
    size: int = Query(20, ge=1, le=100),
    status_filter: Optional[str] = Query(None, alias="status"),
    current_admin: User = Depends(require_moderator_or_admin_role),
    admin_service: AdminService = Depends(get_admin_service),
) -> ApiResponse[Dict[str, Any]]:
    """Queue of listener applications to become creators."""
    items, total = await admin_service.list_creator_applications(
        page=page, size=size, status=status_filter
    )
    return ApiResponse(
        data={
            "items": [
                CreatorApplicationItem(
                    id=app.id,
                    user_id=app.user_id,
                    user_email=app.user.email if app.user else None,
                    user_name=app.user.name if app.user else None,
                    artist_name=app.artist_name,
                    bio=app.bio,
                    genres=app.genres,
                    portfolio_url=app.portfolio_url,
                    status=app.status,
                    reviewer_id=app.reviewer_id,
                    review_notes=app.review_notes,
                    created_at=app.created_at,
                    reviewed_at=app.reviewed_at,
                )
                for app in items
            ],
            "total": total,
            "page": page,
            "size": size,
            "total_pages": (total + size - 1) // size if total > 0 else 1,
        }
    )


@router.patch(
    "/creator-applications/{app_id}",
    response_model=ApiResponse[CreatorApplicationItem],
    status_code=status.HTTP_200_OK,
    summary="Review creator application (Approve/Reject)",
)
async def review_creator_application(
    app_id: uuid.UUID,
    payload: ReviewApplicationRequest,
    request: Request,
    current_admin: User = Depends(require_moderator_or_admin_role),
    admin_service: AdminService = Depends(get_admin_service),
) -> ApiResponse[CreatorApplicationItem]:
    """Approves application (assigns creator role & profile) or rejects with notes."""
    client_ip = request.client.host if request.client else None
    app = await admin_service.review_creator_application(
        actor=current_admin,
        app_id=app_id,
        status=payload.status,
        review_notes=payload.review_notes,
        ip_address=client_ip,
    )
    return ApiResponse(
        data=CreatorApplicationItem(
            id=app.id,
            user_id=app.user_id,
            user_email=app.user.email if app.user else None,
            user_name=app.user.name if app.user else None,
            artist_name=app.artist_name,
            bio=app.bio,
            genres=app.genres,
            portfolio_url=app.portfolio_url,
            status=app.status,
            reviewer_id=app.reviewer_id,
            review_notes=app.review_notes,
            created_at=app.created_at,
            reviewed_at=app.reviewed_at,
        )
    )


# ============================================================================
# 4. Content Management & Moderation
# ============================================================================

@router.get(
    "/tracks",
    response_model=ApiResponse[Dict[str, Any]],
    status_code=status.HTTP_200_OK,
    summary="List catalog tracks with status and filters",
)
async def list_tracks(
    page: int = Query(1, ge=1),
    size: int = Query(20, ge=1, le=100),
    search: Optional[str] = Query(None),
    status_filter: Optional[str] = Query(None, alias="status"),
    genre: Optional[str] = Query(None),
    current_admin: User = Depends(require_moderator_or_admin_role),
    admin_service: AdminService = Depends(get_admin_service),
) -> ApiResponse[Dict[str, Any]]:
    """Tracks catalog for administrative monitoring and moderation."""
    items, total = await admin_service.list_tracks(
        page=page, size=size, search=search, status=status_filter, genre=genre
    )
    return ApiResponse(
        data={
            "items": [AdminTrackItem.model_validate(t) for t in items],
            "total": total,
            "page": page,
            "size": size,
            "total_pages": (total + size - 1) // size if total > 0 else 1,
        }
    )


@router.get(
    "/tracks/{track_id}",
    response_model=ApiResponse[AdminTrackDetail],
    status_code=status.HTTP_200_OK,
    summary="Get track detail for admin inspection",
)
async def get_track_detail(
    track_id: uuid.UUID,
    current_admin: User = Depends(require_moderator_or_admin_role),
    admin_service: AdminService = Depends(get_admin_service),
) -> ApiResponse[AdminTrackDetail]:
    """Full track metadata with processing history and renditions."""
    track = await admin_service.get_track_detail(track_id)
    return ApiResponse(data=AdminTrackDetail.model_validate(track))


@router.patch(
    "/tracks/{track_id}/status",
    response_model=ApiResponse[AdminTrackDetail],
    status_code=status.HTTP_200_OK,
    summary="Moderate track status (READY, MODERATED, FAILED)",
)
async def moderate_track(
    track_id: uuid.UUID,
    payload: ModerateTrackRequest,
    request: Request,
    current_admin: User = Depends(require_moderator_or_admin_role),
    admin_service: AdminService = Depends(get_admin_service),
) -> ApiResponse[AdminTrackDetail]:
    """Moderates track visibility or flags violations with audit logging."""
    client_ip = request.client.host if request.client else None
    result = await admin_service.moderate_track(
        actor=current_admin,
        track_id=track_id,
        status=payload.status,
        reason=payload.reason,
        ip_address=client_ip,
    )
    return ApiResponse(data=AdminTrackDetail.model_validate(result))


@router.post(
    "/tracks/{track_id}/retry",
    response_model=ApiResponse[Dict[str, str]],
    status_code=status.HTTP_200_OK,
    summary="Retry failed transcoding job",
)
async def retry_track_processing(
    track_id: uuid.UUID,
    request: Request,
    current_admin: User = Depends(require_moderator_or_admin_role),
    admin_service: AdminService = Depends(get_admin_service),
) -> ApiResponse[Dict[str, str]]:
    """Queues a Celery transcode job retry for a failed track."""
    client_ip = request.client.host if request.client else None
    result = await admin_service.retry_track_processing(
        actor=current_admin, track_id=track_id, ip_address=client_ip
    )
    return ApiResponse(data=result)


# ============================================================================
# 5. Reports & Moderation Queue
# ============================================================================

@router.get(
    "/reports",
    response_model=ApiResponse[Dict[str, Any]],
    status_code=status.HTTP_200_OK,
    summary="List content violation reports queue",
)
async def list_reports(
    page: int = Query(1, ge=1),
    size: int = Query(20, ge=1, le=100),
    status_filter: Optional[str] = Query(None, alias="status"),
    reason: Optional[str] = Query(None),
    entity_type: Optional[str] = Query(None),
    current_admin: User = Depends(require_moderator_or_admin_role),
    admin_service: AdminService = Depends(get_admin_service),
) -> ApiResponse[Dict[str, Any]]:
    """Reports queue with status and violation reason filters."""
    items, total = await admin_service.list_reports(
        page=page, size=size, status=status_filter, reason=reason, entity_type=entity_type
    )
    return ApiResponse(
        data={
            "items": [
                ContentReportItem(
                    id=r.id,
                    reporter_id=r.reporter_id,
                    reporter_email=r.reporter.email if r.reporter else None,
                    entity_type=r.entity_type,
                    entity_id=r.entity_id,
                    reason=r.reason,
                    description=r.description,
                    status=r.status,
                    moderator_id=r.moderator_id,
                    resolution_notes=r.resolution_notes,
                    action_taken=r.action_taken,
                    created_at=r.created_at,
                    resolved_at=r.resolved_at,
                )
                for r in items
            ],
            "total": total,
            "page": page,
            "size": size,
            "total_pages": (total + size - 1) // size if total > 0 else 1,
        }
    )


@router.patch(
    "/reports/{report_id}",
    response_model=ApiResponse[ContentReportItem],
    status_code=status.HTTP_200_OK,
    summary="Resolve or dismiss content report",
)
async def resolve_report(
    report_id: uuid.UUID,
    payload: ResolveReportRequest,
    request: Request,
    current_admin: User = Depends(require_moderator_or_admin_role),
    admin_service: AdminService = Depends(get_admin_service),
) -> ApiResponse[ContentReportItem]:
    """Records moderation decision and updates violation status."""
    client_ip = request.client.host if request.client else None
    report = await admin_service.resolve_report(
        actor=current_admin,
        report_id=report_id,
        status=payload.status,
        resolution_notes=payload.resolution_notes,
        action_taken=payload.action_taken,
        ip_address=client_ip,
    )
    return ApiResponse(
        data=ContentReportItem(
            id=report.id,
            reporter_id=report.reporter_id,
            entity_type=report.entity_type,
            entity_id=report.entity_id,
            reason=report.reason,
            description=report.description,
            status=report.status,
            moderator_id=report.moderator_id,
            resolution_notes=report.resolution_notes,
            action_taken=report.action_taken,
            created_at=report.created_at,
            resolved_at=report.resolved_at,
        )
    )


# ============================================================================
# 6. Platform Operations & Health
# ============================================================================

@router.get(
    "/operations/health",
    response_model=ApiResponse[SystemHealthStatus],
    status_code=status.HTTP_200_OK,
    summary="Check real-time health of all platform dependencies",
)
async def get_system_health(
    current_admin: User = Depends(require_admin_role),
    admin_service: AdminService = Depends(get_admin_service),
) -> ApiResponse[SystemHealthStatus]:
    """Probes PostgreSQL, Redis, Celery broker, and MinIO object storage."""
    health = await admin_service.get_system_health()
    return ApiResponse(data=health)


@router.get(
    "/operations/jobs",
    response_model=ApiResponse[Dict[str, Any]],
    status_code=status.HTTP_200_OK,
    summary="List media processing jobs",
)
async def list_processing_jobs(
    page: int = Query(1, ge=1),
    size: int = Query(20, ge=1, le=100),
    status_filter: Optional[str] = Query(None, alias="status"),
    current_admin: User = Depends(require_admin_role),
    admin_service: AdminService = Depends(get_admin_service),
) -> ApiResponse[Dict[str, Any]]:
    """Lists transcoding jobs and failure logs."""
    items, total = await admin_service.list_processing_jobs(
        page=page, size=size, status=status_filter
    )
    return ApiResponse(
        data={
            "items": [ProcessingJobItem.model_validate(j) for j in items],
            "total": total,
            "page": page,
            "size": size,
            "total_pages": (total + size - 1) // size if total > 0 else 1,
        }
    )


# ============================================================================
# 7. Audit Logs
# ============================================================================

@router.get(
    "/audit-logs",
    response_model=ApiResponse[Dict[str, Any]],
    status_code=status.HTTP_200_OK,
    summary="Search immutable administrative audit logs",
)
async def list_audit_logs(
    page: int = Query(1, ge=1),
    size: int = Query(20, ge=1, le=100),
    action: Optional[str] = Query(None),
    target_type: Optional[str] = Query(None),
    search: Optional[str] = Query(None),
    current_admin: User = Depends(require_admin_role),
    admin_service: AdminService = Depends(get_admin_service),
) -> ApiResponse[Dict[str, Any]]:
    """Administrative action logs for audit trails."""
    items, total = await admin_service.list_audit_logs(
        page=page, size=size, action=action, target_type=target_type, search=search
    )
    return ApiResponse(
        data={
            "items": [AdminAuditLogItem.model_validate(l) for l in items],
            "total": total,
            "page": page,
            "size": size,
            "total_pages": (total + size - 1) // size if total > 0 else 1,
        }
    )
