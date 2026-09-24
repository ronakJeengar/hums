from typing import Optional
from fastapi import APIRouter, Depends, Query, status

from app.core.dependencies import get_optional_current_user, get_search_service
from app.db.models.user import User
from app.schemas.common import ApiResponse
from app.schemas.search import SearchResponse, SearchType
from app.services.search_service import SearchService

router = APIRouter()


@router.get(
    "",
    response_model=ApiResponse[SearchResponse],
    status_code=status.HTTP_200_OK,
    summary="Search catalog content",
    description=(
        "Executes backend-driven full-text, substring, and trigram-ranked relevance search "
        "across tracks, artists/creators, and playlists with strict privacy isolation."
    ),
)
async def search_catalog(
    q: str = Query("", description="Search query string"),
    type: SearchType = Query(SearchType.ALL, description="Entity type filter: all, tracks, artists, playlists"),
    limit: int = Query(20, ge=1, le=50, description="Maximum results per entity (1-50, default 20)"),
    skip: int = Query(0, ge=0, description="Pagination offset for filtered queries"),
    current_user: Optional[User] = Depends(get_optional_current_user),
    search_service: SearchService = Depends(get_search_service),
) -> ApiResponse[SearchResponse]:
    """
    Search endpoint returning relevance-ordered tracks, artists, and playlists.
    Only returns READY tracks and public/owned playlists.
    """
    current_user_id = current_user.id if current_user else None
    results = await search_service.search(
        query=q,
        search_type=type,
        limit=limit,
        skip=skip,
        current_user_id=current_user_id,
    )
    return ApiResponse(data=results)
