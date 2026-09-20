import io
import logging
import uuid
from typing import Optional
from PIL import Image, ImageOps
from fastapi import UploadFile

from app.core.config import get_settings
from app.core.errors import BadRequestError, ConflictError, NotFoundError
from app.db.models.user import User
from app.repositories.user_repository import UserRepository
from app.schemas.profile import ProfileResponse, ProfileUpdateRequest
from app.utils.storage import BaseStorageService

logger = logging.getLogger("hums.profile_service")
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


class ProfileService:
    """Service handling user profile retrieval, updates, and avatar management."""

    def __init__(
        self,
        user_repository: UserRepository,
        storage_service: BaseStorageService,
    ):
        self.user_repo = user_repository
        self.storage_service = storage_service

    def _to_response(self, user: User) -> ProfileResponse:
        """Converts User database model to safe ProfileResponse schema."""
        return ProfileResponse(
            id=user.id,
            name=user.name,
            email=user.email,
            username=user.username,
            avatar_url=user.avatar_url,
            bio=user.bio,
            created_at=user.created_at,
            updated_at=user.updated_at,
        )

    async def get_profile(self, user: User) -> ProfileResponse:
        """Returns the profile of the authenticated user."""
        return self._to_response(user)

    async def update_profile(
        self,
        user: User,
        update_data: ProfileUpdateRequest,
    ) -> ProfileResponse:
        """Updates authenticated user's profile details."""
        updates = update_data.model_dump(exclude_unset=True)

        name_to_update: Optional[str] = None
        email_to_update: Optional[str] = None
        bio_to_update: Optional[str] = None

        if "name" in updates:
            raw_name = updates["name"]
            if raw_name is None or len(raw_name.strip()) < 2:
                raise BadRequestError(
                    "Name must be at least 2 characters long.",
                    code="INVALID_PROFILE_DATA",
                )
            name_to_update = raw_name.strip()

        if "email" in updates:
            raw_email = updates["email"]
            if not raw_email or not raw_email.strip():
                raise BadRequestError(
                    "Email cannot be empty.",
                    code="INVALID_PROFILE_DATA",
                )
            normalized_email = raw_email.strip().lower()
            if normalized_email != user.email.lower():
                existing = await self.user_repo.get_by_email(normalized_email)
                if existing and existing.id != user.id:
                    raise ConflictError(
                        "A user with this email already exists.",
                        code="EMAIL_ALREADY_EXISTS",
                    )
                email_to_update = normalized_email

        if "bio" in updates:
            raw_bio = updates["bio"]
            if raw_bio is not None:
                stripped_bio = raw_bio.strip()
                if len(stripped_bio) > 500:
                    raise BadRequestError(
                        "Bio must not exceed 500 characters.",
                        code="INVALID_PROFILE_DATA",
                    )
                bio_to_update = stripped_bio if stripped_bio else None
            else:
                bio_to_update = None

        updated_user = await self.user_repo.update_profile(
            user,
            name=name_to_update,
            email=email_to_update,
            bio=bio_to_update,
        )

        return self._to_response(updated_user)

    async def upload_avatar(
        self,
        user: User,
        file: UploadFile,
    ) -> ProfileResponse:
        """Validates, processes, and uploads a new avatar for the authenticated user."""
        # 1. Validate MIME type
        content_type = file.content_type.lower() if file.content_type else ""
        if content_type not in ALLOWED_MIME_TYPES:
            raise BadRequestError(
                "Unsupported image type. Allowed formats: JPEG, PNG, WebP.",
                code="UNSUPPORTED_IMAGE_TYPE",
            )

        # 2. Validate file size
        max_bytes = settings.MAX_AVATAR_SIZE_MB * 1024 * 1024
        file_bytes = await file.read()

        if len(file_bytes) == 0:
            raise BadRequestError(
                "Avatar image cannot be empty.",
                code="INVALID_IMAGE",
            )

        if len(file_bytes) > max_bytes:
            raise BadRequestError(
                f"Avatar image exceeds the {settings.MAX_AVATAR_SIZE_MB}MB size limit.",
                code="IMAGE_TOO_LARGE",
            )

        # 3. Validate image integrity and format with Pillow
        try:
            image_stream = io.BytesIO(file_bytes)
            img = Image.open(image_stream)
            img.verify()  # Verifies file integrity/magic bytes

            # Re-open after verify() as verify can close/corrupt internal buffer
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

            # 4. Process image: auto-orient, resize keeping aspect ratio, strip metadata
            img = ImageOps.exif_transpose(img)

            if width > TARGET_MAX_DIMENSION or height > TARGET_MAX_DIMENSION:
                img.thumbnail((TARGET_MAX_DIMENSION, TARGET_MAX_DIMENSION), Image.Resampling.LANCZOS)

            # Convert to WebP for optimized size and broad cross-platform compatibility
            output_stream = io.BytesIO()
            if img.mode not in ("RGB", "RGBA"):
                img = img.convert("RGBA")

            img.save(output_stream, format="WEBP", quality=85, method=6)
            processed_bytes = output_stream.getvalue()

        except BadRequestError:
            raise
        except Exception as e:
            logger.warning(f"Image validation failed for user {user.id}: {e}")
            raise BadRequestError(
                "Invalid or corrupted image file.",
                code="INVALID_IMAGE",
            )

        # 5. Generate safe object key and upload to storage
        unique_id = uuid.uuid4().hex
        object_key = f"avatars/{user.id}/{unique_id}.webp"

        try:
            await self.storage_service.upload_file(
                processed_bytes,
                object_key,
                content_type="image/webp",
            )
        except Exception as e:
            logger.error(f"Failed to upload avatar to storage for user {user.id}: {e}")
            raise BadRequestError(
                "Failed to store avatar image. Please try again later.",
                code="AVATAR_UPLOAD_FAILED",
                status_code=500,
            )

        new_avatar_url = await self.storage_service.get_download_url(object_key)

        # 6. Save new reference and safely delete old avatar
        old_avatar_url = user.avatar_url
        updated_user = await self.user_repo.update_profile(
            user,
            avatar_url=new_avatar_url,
        )

        if old_avatar_url:
            await self.storage_service.delete_file(old_avatar_url)

        return self._to_response(updated_user)

    async def remove_avatar(self, user: User) -> ProfileResponse:
        """Removes authenticated user's avatar from storage and updates profile."""
        old_avatar_url = user.avatar_url

        if old_avatar_url:
            await self.storage_service.delete_file(old_avatar_url)
            updated_user = await self.user_repo.update_profile(
                user,
                clear_avatar=True,
            )
            return self._to_response(updated_user)

        return self._to_response(user)
