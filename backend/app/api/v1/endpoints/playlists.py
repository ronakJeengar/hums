import uuid
from typing import Any, Dict, List, Optional
from fastapi import APIRouter, Depends, File, Query, UploadFile, status

from app.core.dependencies import get_current_user, get_playlist_service
from app.core.rate_limit import RateLimiter
from app.db.models.user import User
from app.schemas.common import ApiResponse
from app.schemas.playlist import (
    PlaylistCreate,
    PlaylistDetailResponse,
    PlaylistResponse,
    PlaylistTrackAdd,
    PlaylistTracksReorder,
    PlaylistUpdate,
)
from app.services.playlist_service import PlaylistService

router = APIRouter()


@router.post(
    "",
    response_model=ApiResponse[PlaylistResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Create a new playlist",
    description="Creates a user-owned playlist with name and optional description.",
    dependencies=[Depends(RateLimiter(requests=30, window_seconds=60, action="playlist_create"))],
)
async def create_playlist(
    body: PlaylistCreate,
    current_user: User = Depends(get_current_user),
    playlist_service: PlaylistService = Depends(get_playlist_service),
) -> ApiResponse[PlaylistResponse]:
    playlist = await playlist_service.create_playlist(current_user, body)
    return ApiResponse(data=playlist)


@router.get(
    "",
    response_model=ApiResponse[List[PlaylistResponse]],
    status_code=status.HTTP_200_OK,
    summary="List user playlists",
    description="Returns a paginated list of playlists owned by the authenticated user.",
)
async def list_playlists(
    skip: int = Query(0, ge=0, description="Offset for pagination"),
    limit: int = Query(50, ge=1, le=100, description="Page size limit"),
    current_user: User = Depends(get_current_user),
    playlist_service: PlaylistService = Depends(get_playlist_service),
) -> ApiResponse[List[PlaylistResponse]]:
    playlists = await playlist_service.list_playlists(current_user, skip=skip, limit=limit)
    return ApiResponse(data=playlists)


@router.get(
    "/{playlist_id}",
    response_model=ApiResponse[PlaylistDetailResponse],
    status_code=status.HTTP_200_OK,
    summary="Get playlist details",
    description="Returns complete playlist details with all ordered track items.",
)
async def get_playlist(
    playlist_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    playlist_service: PlaylistService = Depends(get_playlist_service),
) -> ApiResponse[PlaylistDetailResponse]:
    playlist = await playlist_service.get_playlist_details(playlist_id, current_user)
    return ApiResponse(data=playlist)


@router.patch(
    "/{playlist_id}",
    response_model=ApiResponse[PlaylistResponse],
    status_code=status.HTTP_200_OK,
    summary="Update playlist metadata",
    description="Updates name, description, or visibility for a user-owned playlist.",
)
async def update_playlist(
    playlist_id: uuid.UUID,
    body: PlaylistUpdate,
    current_user: User = Depends(get_current_user),
    playlist_service: PlaylistService = Depends(get_playlist_service),
) -> ApiResponse[PlaylistResponse]:
    playlist = await playlist_service.update_playlist(playlist_id, current_user, body)
    return ApiResponse(data=playlist)


@router.delete(
    "/{playlist_id}",
    response_model=ApiResponse[Dict[str, str]],
    status_code=status.HTTP_200_OK,
    summary="Delete playlist",
    description="Permanently deletes a playlist, its track memberships, and its cover image.",
)
async def delete_playlist(
    playlist_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    playlist_service: PlaylistService = Depends(get_playlist_service),
) -> ApiResponse[Dict[str, str]]:
    await playlist_service.delete_playlist(playlist_id, current_user)
    return ApiResponse(data={"message": "Playlist deleted successfully"})


@router.post(
    "/{playlist_id}/cover",
    response_model=ApiResponse[PlaylistResponse],
    status_code=status.HTTP_200_OK,
    summary="Upload playlist cover artwork",
    description="Uploads and processes artwork image (JPEG, PNG, WebP up to 5MB) for a playlist.",
)
async def upload_cover(
    playlist_id: uuid.UUID,
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    playlist_service: PlaylistService = Depends(get_playlist_service),
) -> ApiResponse[PlaylistResponse]:
    playlist = await playlist_service.upload_cover(playlist_id, current_user, file)
    return ApiResponse(data=playlist)


@router.delete(
    "/{playlist_id}/cover",
    response_model=ApiResponse[PlaylistResponse],
    status_code=status.HTTP_200_OK,
    summary="Remove playlist cover artwork",
    description="Removes cover artwork from a playlist.",
)
async def remove_cover(
    playlist_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    playlist_service: PlaylistService = Depends(get_playlist_service),
) -> ApiResponse[PlaylistResponse]:
    playlist = await playlist_service.remove_cover(playlist_id, current_user)
    return ApiResponse(data=playlist)


@router.post(
    "/{playlist_id}/tracks",
    response_model=ApiResponse[PlaylistDetailResponse],
    status_code=status.HTTP_200_OK,
    summary="Add track to playlist",
    description="Appends a track to the end of the playlist.",
)
async def add_track_to_playlist(
    playlist_id: uuid.UUID,
    body: PlaylistTrackAdd,
    current_user: User = Depends(get_current_user),
    playlist_service: PlaylistService = Depends(get_playlist_service),
) -> ApiResponse[PlaylistDetailResponse]:
    playlist = await playlist_service.add_track(playlist_id, current_user, body)
    return ApiResponse(data=playlist)


@router.delete(
    "/{playlist_id}/tracks/{track_id}",
    response_model=ApiResponse[PlaylistDetailResponse],
    status_code=status.HTTP_200_OK,
    summary="Remove track from playlist",
    description="Removes a track membership and normalizes positions without deleting the track itself.",
)
async def remove_track_from_playlist(
    playlist_id: uuid.UUID,
    track_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    playlist_service: PlaylistService = Depends(get_playlist_service),
) -> ApiResponse[PlaylistDetailResponse]:
    playlist = await playlist_service.remove_track(playlist_id, current_user, track_id)
    return ApiResponse(data=playlist)


@router.patch(
    "/{playlist_id}/tracks/reorder",
    response_model=ApiResponse[PlaylistDetailResponse],
    status_code=status.HTTP_200_OK,
    summary="Reorder tracks in playlist",
    description="Atomically updates track positions based on the submitted list of track IDs.",
)
async def reorder_tracks(
    playlist_id: uuid.UUID,
    body: PlaylistTracksReorder,
    current_user: User = Depends(get_current_user),
    playlist_service: PlaylistService = Depends(get_playlist_service),
) -> ApiResponse[PlaylistDetailResponse]:
    playlist = await playlist_service.reorder_tracks(playlist_id, current_user, body)
    return ApiResponse(data=playlist)
