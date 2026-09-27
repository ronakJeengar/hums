import io
import logging
import uuid
from typing import List

from fastapi import UploadFile
from PIL import Image, ImageOps

from app.core.config import get_settings
from app.core.errors import (
    BadRequestError,
    ConflictError,
    ForbiddenError,
    NotFoundError,
)
from app.db.models.playlist import Playlist
from app.db.models.user import User
from app.repositories.audio_repository import TrackRepository
from app.repositories.playlist_repository import PlaylistRepository
from app.schemas.playlist import (
    PlaylistCreate,
    PlaylistDetailResponse,
    PlaylistResponse,
    PlaylistTrackAdd,
    PlaylistTrackItem,
    PlaylistTracksReorder,
    PlaylistUpdate,
)
from app.utils.storage import BaseStorageService
from app.utils.upload import read_upload_file_bounded

logger = logging.getLogger("hums.playlist_service")
settings = get_settings()

ALLOWED_MIME_TYPES = {
    "image/jpeg": "JPEG",
    "image/png": "PNG",
    "image/webp": "WEBP",
}
ALLOWED_FORMATS = {"JPEG", "PNG", "WEBP"}
MIN_DIMENSION = 32
MAX_DIMENSION = 4096
TARGET_MAX_DIMENSION = 1024


class PlaylistService:
    """Service orchestrating playlist domain logic, ownership, and media storage."""

    def __init__(
        self,
        playlist_repository: PlaylistRepository,
        track_repository: TrackRepository,
        storage_service: BaseStorageService,
    ):
        self.playlist_repo = playlist_repository
        self.track_repo = track_repository
        self.storage_service = storage_service

    async def _to_response(self, playlist: Playlist) -> PlaylistResponse:
        """Converts Playlist DB model to PlaylistResponse schema."""
        cover_url = None
        if playlist.cover_image_key:
            cover_url = await self.storage_service.get_download_url(
                playlist.cover_image_key
            )

        from sqlalchemy import inspect

        insp = inspect(playlist)
        if "playlist_tracks" in insp.unloaded:
            track_count = 0
            duration_seconds = 0
        else:
            track_count = (
                len(playlist.playlist_tracks) if playlist.playlist_tracks else 0
            )
            duration_seconds = sum(
                (pt.track.duration_seconds or 0)
                for pt in (playlist.playlist_tracks or [])
                if pt.track and "track" not in inspect(pt).unloaded
            )

        return PlaylistResponse(
            id=playlist.id,
            owner_id=playlist.owner_id,
            name=playlist.name,
            description=playlist.description,
            cover_image_key=playlist.cover_image_key,
            cover_image_url=cover_url,
            is_public=playlist.is_public,
            track_count=track_count,
            duration_seconds=duration_seconds,
            created_at=playlist.created_at,
            updated_at=playlist.updated_at,
        )

    async def _to_detail_response(self, playlist: Playlist) -> PlaylistDetailResponse:
        """Converts Playlist DB model to PlaylistDetailResponse with ordered track items."""
        cover_url = None
        if playlist.cover_image_key:
            cover_url = await self.storage_service.get_download_url(
                playlist.cover_image_key
            )

        tracks: List[PlaylistTrackItem] = []
        duration_seconds = 0

        # Ordered by position
        sorted_pts = sorted(
            playlist.playlist_tracks or [],
            key=lambda pt: pt.position,
        )

        for pt in sorted_pts:
            track = pt.track
            if track:
                if track.duration_seconds:
                    duration_seconds += track.duration_seconds
                tracks.append(
                    PlaylistTrackItem(
                        id=pt.id,
                        track_id=pt.track_id,
                        position=pt.position,
                        added_at=pt.added_at,
                        title=track.title,
                        artist_name=track.artist_name,
                        album_name=track.album_name,
                        duration_seconds=track.duration_seconds,
                        waveform_key=track.waveform_key,
                        status=track.status,
                    )
                )

        return PlaylistDetailResponse(
            id=playlist.id,
            owner_id=playlist.owner_id,
            name=playlist.name,
            description=playlist.description,
            cover_image_key=playlist.cover_image_key,
            cover_image_url=cover_url,
            is_public=playlist.is_public,
            track_count=len(tracks),
            duration_seconds=duration_seconds,
            created_at=playlist.created_at,
            updated_at=playlist.updated_at,
            tracks=tracks,
        )

    def _verify_ownership(self, playlist: Playlist, user: User) -> None:
        """Enforces that the authenticated user is the true owner of the playlist."""
        if playlist.owner_id != user.id:
            raise ForbiddenError(
                "You do not have permission to modify this playlist.",
                code="FORBIDDEN",
            )

    async def create_playlist(
        self, user: User, data: PlaylistCreate
    ) -> PlaylistResponse:
        """Creates a new user-owned playlist."""
        playlist = await self.playlist_repo.create(
            owner_id=user.id,
            name=data.name,
            description=data.description,
            is_public=False,
        )
        return await self._to_response(playlist)

    async def list_playlists(
        self, user: User, skip: int = 0, limit: int = 50
    ) -> List[PlaylistResponse]:
        """Lists all playlists owned by the authenticated user with pre-aggregated counts and durations."""
        records = await self.playlist_repo.list_by_owner_with_aggregates(
            user.id, skip=skip, limit=limit
        )
        responses: List[PlaylistResponse] = []
        for playlist, track_count, duration_seconds in records:
            cover_url = None
            if playlist.cover_image_key:
                cover_url = await self.storage_service.get_download_url(
                    playlist.cover_image_key
                )
            responses.append(
                PlaylistResponse(
                    id=playlist.id,
                    owner_id=playlist.owner_id,
                    name=playlist.name,
                    description=playlist.description,
                    cover_image_key=playlist.cover_image_key,
                    cover_image_url=cover_url,
                    is_public=playlist.is_public,
                    track_count=track_count,
                    duration_seconds=duration_seconds,
                    created_at=playlist.created_at,
                    updated_at=playlist.updated_at,
                )
            )
        return responses

    async def get_playlist_details(
        self, playlist_id: uuid.UUID, user: User
    ) -> PlaylistDetailResponse:
        """Retrieves complete details of a playlist including all ordered tracks."""
        playlist = await self.playlist_repo.get_by_id_with_tracks(playlist_id)
        if not playlist:
            raise NotFoundError("Playlist not found")

        # Access check: owner or public
        if playlist.owner_id != user.id and not playlist.is_public:
            raise ForbiddenError(
                "You do not have permission to view this playlist.",
                code="FORBIDDEN",
            )

        return await self._to_detail_response(playlist)

    async def update_playlist(
        self, playlist_id: uuid.UUID, user: User, data: PlaylistUpdate
    ) -> PlaylistResponse:
        """Updates playlist name, description, or visibility."""
        playlist = await self.playlist_repo.get_by_id_with_tracks(playlist_id)
        if not playlist:
            raise NotFoundError("Playlist not found")

        self._verify_ownership(playlist, user)

        if data.name is not None:
            playlist.name = data.name
        if data.description is not None:
            playlist.description = data.description
        if data.is_public is not None:
            playlist.is_public = data.is_public

        await self.playlist_repo.session.flush()
        await self.playlist_repo.session.refresh(playlist)
        return await self._to_response(playlist)

    async def delete_playlist(self, playlist_id: uuid.UUID, user: User) -> None:
        """Deletes a playlist and cascades to memberships, cleaning up cover storage."""
        playlist = await self.playlist_repo.get_by_id(playlist_id)
        if not playlist:
            raise NotFoundError("Playlist not found")

        self._verify_ownership(playlist, user)

        # Clean up cover image if present
        if playlist.cover_image_key:
            try:
                await self.storage_service.delete_file(playlist.cover_image_key)
            except Exception as e:
                logger.warning(
                    f"Failed to delete cover image {playlist.cover_image_key}: {e}"
                )

        await self.playlist_repo.delete(playlist.id)

    async def upload_cover(
        self, playlist_id: uuid.UUID, user: User, file: UploadFile
    ) -> PlaylistResponse:
        """Validates and uploads playlist cover artwork to object storage."""
        playlist = await self.playlist_repo.get_by_id_with_tracks(playlist_id)
        if not playlist:
            raise NotFoundError("Playlist not found")

        self._verify_ownership(playlist, user)

        content_type = file.content_type.lower() if file.content_type else ""
        if content_type not in ALLOWED_MIME_TYPES:
            raise BadRequestError(
                "Unsupported image type. Allowed formats: JPEG, PNG, WebP.",
                code="UNSUPPORTED_IMAGE_TYPE",
            )

        # 2. Validate file size with bounded streaming
        max_bytes = settings.MAX_AVATAR_SIZE_MB * 1024 * 1024
        file_bytes = await read_upload_file_bounded(
            file,
            max_bytes=max_bytes,
            error_code="IMAGE_TOO_LARGE",
            error_message=f"Cover image exceeds the {settings.MAX_AVATAR_SIZE_MB}MB size limit.",
        )

        if len(file_bytes) == 0:
            raise BadRequestError("Cover image cannot be empty.", code="INVALID_IMAGE")

        try:
            image_stream = io.BytesIO(file_bytes)
            img = Image.open(image_stream)
            img.verify()

            image_stream.seek(0)
            img = Image.open(image_stream)
            img_format = img.format.upper() if img.format else ""

            if img_format not in ALLOWED_FORMATS:
                raise BadRequestError(
                    "Unsupported image format. Allowed formats: JPEG, PNG, WebP.",
                    code="UNSUPPORTED_IMAGE_TYPE",
                )

            width, height = img.size
            if width < MIN_DIMENSION or height < MIN_DIMENSION:
                raise BadRequestError(
                    f"Image is too small. Minimum dimensions are {MIN_DIMENSION}x{MIN_DIMENSION}.",
                    code="INVALID_IMAGE",
                )
            if width > MAX_DIMENSION or height > MAX_DIMENSION:
                raise BadRequestError(
                    f"Image is too large. Maximum dimensions are {MAX_DIMENSION}x{MAX_DIMENSION}.",
                    code="INVALID_IMAGE",
                )

            img = ImageOps.exif_transpose(img)
            if width > TARGET_MAX_DIMENSION or height > TARGET_MAX_DIMENSION:
                img.thumbnail(
                    (TARGET_MAX_DIMENSION, TARGET_MAX_DIMENSION),
                    Image.Resampling.LANCZOS,
                )

            output_stream = io.BytesIO()
            if img.mode not in ("RGB", "RGBA"):
                img = img.convert("RGBA")

            img.save(output_stream, format="WEBP", quality=85, method=6)
            processed_bytes = output_stream.getvalue()

        except BadRequestError:
            raise
        except Exception as e:
            logger.warning(f"Playlist cover image validation failed: {e}")
            raise BadRequestError(
                "Invalid or corrupted image file.", code="INVALID_IMAGE"
            )

        # Generate unique storage key
        unique_id = uuid.uuid4().hex
        object_key = f"playlists/{user.id}/{playlist.id}/{unique_id}.webp"

        try:
            await self.storage_service.upload_file(
                processed_bytes,
                object_key,
                content_type="image/webp",
            )
        except Exception as e:
            logger.error(f"Failed to upload playlist cover to storage: {e}")
            raise BadRequestError(
                "Failed to store cover image. Please try again later.",
                code="COVER_UPLOAD_FAILED",
                status_code=500,
            )

        # Cleanup old cover
        old_cover_key = playlist.cover_image_key
        playlist.cover_image_key = object_key
        await self.playlist_repo.session.flush()
        await self.playlist_repo.session.refresh(playlist)

        if old_cover_key:
            try:
                await self.storage_service.delete_file(old_cover_key)
            except Exception as e:
                logger.warning(f"Failed to delete old cover image {old_cover_key}: {e}")

        return await self._to_response(playlist)

    async def remove_cover(
        self, playlist_id: uuid.UUID, user: User
    ) -> PlaylistResponse:
        """Removes cover artwork from a playlist."""
        playlist = await self.playlist_repo.get_by_id_with_tracks(playlist_id)
        if not playlist:
            raise NotFoundError("Playlist not found")

        self._verify_ownership(playlist, user)

        old_cover_key = playlist.cover_image_key
        if old_cover_key:
            try:
                await self.storage_service.delete_file(old_cover_key)
            except Exception as e:
                logger.warning(f"Failed to delete cover image {old_cover_key}: {e}")
            playlist.cover_image_key = None
            await self.playlist_repo.session.flush()
            await self.playlist_repo.session.refresh(playlist)

        return await self._to_response(playlist)

    async def add_track(
        self, playlist_id: uuid.UUID, user: User, data: PlaylistTrackAdd
    ) -> PlaylistDetailResponse:
        """Adds a track to the end of the playlist."""
        playlist = await self.playlist_repo.get_by_id_with_tracks(playlist_id)
        if not playlist:
            raise NotFoundError("Playlist not found")

        self._verify_ownership(playlist, user)

        # Verify track exists and is not failed
        track = await self.track_repo.get_by_id(data.track_id)
        if not track:
            raise NotFoundError("Track not found")
        if track.status == "FAILED":
            raise BadRequestError(
                "Failed tracks cannot be added to playlists.",
                code="TRACK_FAILED",
            )

        # Check for duplicate track in playlist
        existing = await self.playlist_repo.get_playlist_track(
            playlist_id, data.track_id
        )
        if existing:
            raise ConflictError(
                "Track is already in this playlist",
                code="TRACK_ALREADY_IN_PLAYLIST",
            )

        max_pos = await self.playlist_repo.get_max_position(playlist_id)
        new_pos = max_pos + 1

        await self.playlist_repo.add_track(playlist_id, data.track_id, new_pos)
        self.playlist_repo.session.expire(playlist, ["playlist_tracks"])

        # Refetch fresh details
        updated_playlist = await self.playlist_repo.get_by_id_with_tracks(playlist_id)
        return await self._to_detail_response(updated_playlist)

    async def remove_track(
        self, playlist_id: uuid.UUID, user: User, track_id: uuid.UUID
    ) -> PlaylistDetailResponse:
        """Removes a track from the playlist and renumbers positions atomically."""
        playlist = await self.playlist_repo.get_by_id_with_tracks(playlist_id)
        if not playlist:
            raise NotFoundError("Playlist not found")

        self._verify_ownership(playlist, user)

        existing = await self.playlist_repo.get_playlist_track(playlist_id, track_id)
        if not existing:
            raise NotFoundError("Track is not in this playlist")

        await self.playlist_repo.remove_track_and_renumber(playlist_id, track_id)
        self.playlist_repo.session.expire(playlist, ["playlist_tracks"])

        # Refetch fresh details
        updated_playlist = await self.playlist_repo.get_by_id_with_tracks(playlist_id)
        return await self._to_detail_response(updated_playlist)

    async def reorder_tracks(
        self, playlist_id: uuid.UUID, user: User, data: PlaylistTracksReorder
    ) -> PlaylistDetailResponse:
        """Reorders all tracks in the playlist atomically."""
        playlist = await self.playlist_repo.get_by_id_with_tracks(playlist_id)
        if not playlist:
            raise NotFoundError("Playlist not found")

        self._verify_ownership(playlist, user)

        current_track_ids = {pt.track_id for pt in (playlist.playlist_tracks or [])}
        submitted_track_ids = set(data.track_ids)

        if current_track_ids != submitted_track_ids:
            raise BadRequestError(
                "Invalid track IDs for reordering. Must match exact set of tracks in playlist.",
                code="INVALID_TRACK_IDS",
            )

        await self.playlist_repo.reorder_tracks(playlist_id, data.track_ids)
        self.playlist_repo.session.expire(playlist, ["playlist_tracks"])

        # Refetch fresh details
        updated_playlist = await self.playlist_repo.get_by_id_with_tracks(playlist_id)
        return await self._to_detail_response(updated_playlist)
