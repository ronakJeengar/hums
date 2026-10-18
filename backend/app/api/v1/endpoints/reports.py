import uuid
from typing import Optional
from fastapi import APIRouter, Depends, status

from app.core.dependencies import get_creator_studio_service, get_current_user
from app.db.models.user import User
from app.schemas.admin import ContentReportItem, CreateReportRequest
from app.schemas.common import ApiResponse
from app.services.creator_studio_service import CreatorStudioService

router = APIRouter(prefix="/reports", tags=["Content Moderation Reports"])


@router.post(
    "",
    response_model=ApiResponse[ContentReportItem],
    status_code=status.HTTP_201_CREATED,
    summary="Submit content violation report",
)
async def create_report(
    payload: CreateReportRequest,
    current_user: User = Depends(get_current_user),
    studio_service: CreatorStudioService = Depends(get_creator_studio_service),
) -> ApiResponse[ContentReportItem]:
    """Allows any logged in user to flag a track, creator, or user for moderation."""
    report = await studio_service.create_content_report(
        reporter_id=current_user.id,
        entity_type=payload.entity_type,
        entity_id=payload.entity_id,
        reason=payload.reason,
        description=payload.description,
    )
    return ApiResponse(
        data=ContentReportItem(
            id=report.id,
            reporter_id=report.reporter_id,
            reporter_email=current_user.email,
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
