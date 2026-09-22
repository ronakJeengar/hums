from typing import Optional
from fastapi import APIRouter, Depends, Query, status

from app.core.dependencies import get_current_user, get_recommendation_service
from app.db.models.user import User
from app.schemas.common import ApiResponse
from app.schemas.recommendation import (
    RecommendationRefreshResponse,
    RecommendationResponse,
)
from app.services.recommendation_service import RecommendationService

router = APIRouter()


@router.get(
    "",
    response_model=ApiResponse[RecommendationResponse],
    status_code=status.HTTP_200_OK,
    summary="Get personalized recommendations",
    description="Returns categorized recommendation sections (Recommended for You, Genre-based, Trending, Discover) tailored to the authenticated user.",
)
async def get_recommendations(
    limit: int = Query(10, ge=1, le=50, description="Max tracks per recommendation section"),
    section: Optional[str] = Query(None, description="Optional section filter: 'for-you', 'genre', 'trending', 'discover'"),
    refresh: bool = Query(False, description="Whether to trigger an on-demand recommendation refresh if debounce allows"),
    current_user: User = Depends(get_current_user),
    recommendation_service: RecommendationService = Depends(get_recommendation_service),
) -> ApiResponse[RecommendationResponse]:
    recommendations = await recommendation_service.get_recommendations(
        user=current_user,
        limit=limit,
        section_filter=section,
        refresh=refresh,
    )
    return ApiResponse(data=recommendations)


@router.post(
    "/refresh",
    response_model=ApiResponse[RecommendationRefreshResponse],
    status_code=status.HTTP_202_ACCEPTED,
    summary="Refresh recommendations",
    description="Triggers an asynchronous background regeneration or immediate refresh of recommendations for the authenticated user.",
)
async def refresh_recommendations(
    current_user: User = Depends(get_current_user),
    recommendation_service: RecommendationService = Depends(get_recommendation_service),
) -> ApiResponse[RecommendationRefreshResponse]:
    queued = False
    try:
        from app.workers.recommendation_tasks import generate_user_recommendations
        generate_user_recommendations.delay(str(current_user.id))
        queued = True
        msg = "Recommendation refresh task scheduled"
    except Exception:
        # Fallback to synchronous generation if Celery worker broker is unavailable
        await recommendation_service.get_recommendations(
            user=current_user, refresh=True
        )
        msg = "Recommendations refreshed successfully"

    return ApiResponse(
        data=RecommendationRefreshResponse(
            message=msg,
            queued=queued,
        )
    )
