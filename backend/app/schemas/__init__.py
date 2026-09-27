from app.schemas.common import (
    ApiResponse,
    ErrorResponse,
    ErrorDetail,
    HealthData,
    HealthServiceStatus,
)
from app.schemas.user import (
    UserBase,
    UserCreate,
    UserRead,
    UserLogin,
    TokenResponse,
    TokenPayload,
)
from app.schemas.profile import (
    ProfileResponse,
    ProfileUpdateRequest,
)
from app.schemas.search import (
    SearchType,
    SearchTrackItem,
    SearchArtistItem,
    SearchAlbumItem,
    SearchPlaylistItem,
    SearchPodcastItem,
    SearchEpisodeItem,
    SearchResponse,
    SearchSuggestionsResponse,
)

__all__ = [
    "ApiResponse",
    "ErrorResponse",
    "ErrorDetail",
    "HealthData",
    "HealthServiceStatus",
    "UserBase",
    "UserCreate",
    "UserRead",
    "UserLogin",
    "TokenResponse",
    "TokenPayload",
    "ProfileResponse",
    "ProfileUpdateRequest",
    "SearchType",
    "SearchTrackItem",
    "SearchArtistItem",
    "SearchAlbumItem",
    "SearchPlaylistItem",
    "SearchPodcastItem",
    "SearchEpisodeItem",
    "SearchResponse",
    "SearchSuggestionsResponse",
]
