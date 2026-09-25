
from fastapi import APIRouter, Depends, Query, status

from app.core.dependencies import get_optional_current_user, get_search_service
from app.core.rate_limit import RateLimiter
from app.db.models.user import User
from app.schemas.common import ApiResponse
from app.schemas.search import (
    SearchResponse,
    SearchSuggestionsResponse,
    SearchType,
)
from app.services.search_service import SearchService

router = APIRouter()


@router.get(
    "",
    response_model=ApiResponse[SearchResponse],
    status_code=status.HTTP_200_OK,
    dependencies=[Depends(RateLimiter(requests=60, window_seconds=60, action="search"))],
    summary="Search catalog content",
    description=(
        "Executes backend-driven full-text, substring, and trigram-ranked relevance search "
        "across tracks, artists/creators, albums, playlists, podcasts, and episodes with strict privacy isolation."
    ),
)
async def search_catalog(
    q: str = Query("", description="Search query string"),
    type: SearchType = Query(  # noqa: B008
        SearchType.ALL,
        description="Entity type filter: all, tracks, artists, albums, playlists, podcasts, episodes",
    ),
    limit: int = Query(20, ge=1, le=50, description="Maximum results per entity (1-50, default 20)"),
    skip: int = Query(0, ge=0, description="Pagination offset for filtered queries"),
    current_user: User | None = Depends(get_optional_current_user),  # noqa: B008
    search_service: SearchService = Depends(get_search_service),  # noqa: B008
) -> ApiResponse[SearchResponse]:
    """
    Search endpoint returning relevance-ordered tracks, artists, albums, playlists, podcasts, and episodes.
    Strictly filters out non-READY tracks and private playlists not owned by the requester.
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


@router.get(
    "/suggestions",
    response_model=ApiResponse[SearchSuggestionsResponse],
    status_code=status.HTTP_200_OK,
    dependencies=[Depends(RateLimiter(requests=120, window_seconds=60, action="search_suggestions"))],
    summary="Get search suggestions",
    description=(
        "Returns fast, ranked autocomplete suggestions across tracks, artists, albums, and playlists. "
        "Cached in Redis with short TTL and authorization-aware filtering."
    ),
)
async def get_search_suggestions(
    q: str = Query("", description="Search prefix or partial query"),
    limit: int = Query(8, ge=1, le=20, description="Maximum number of suggestions (1-20, default 8)"),
    current_user: User | None = Depends(get_optional_current_user),  # noqa: B008
    search_service: SearchService = Depends(get_search_service),  # noqa: B008
) -> ApiResponse[SearchSuggestionsResponse]:
    """
    Autocomplete suggestions endpoint returning lightweight candidate strings.
    """
    current_user_id = current_user.id if current_user else None
    suggestions = await search_service.get_suggestions(
        query=q,
        limit=limit,
        current_user_id=current_user_id,
    )
    return ApiResponse(data=suggestions)
