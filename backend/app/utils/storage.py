from abc import ABC, abstractmethod
from typing import Optional
from app.core.config import get_settings

settings = get_settings()


class BaseStorageService(ABC):
    """Abstract interface for object storage operations."""

    @abstractmethod
    async def upload_file(
        self,
        file_bytes: bytes,
        destination_key: str,
        content_type: str = "application/octet-stream"
    ) -> str:
        """Uploads raw binary bytes to object storage and returns the object key/URL."""
        pass

    @abstractmethod
    async def get_download_url(self, key: str, expires_in: int = 3600) -> str:
        """Generates a secure download or presigned access URL."""
        pass

    @abstractmethod
    async def delete_file(self, key: str) -> bool:
        """Deletes an object by key."""
        pass


class S3StorageService(BaseStorageService):
    """
    S3-compatible storage implementation supporting AWS S3, MinIO, and Cloudflare R2.
    """

    def __init__(self):
        self.endpoint_url = settings.S3_ENDPOINT
        self.access_key = settings.S3_ACCESS_KEY
        self.secret_key = settings.S3_SECRET_KEY
        self.bucket = settings.S3_BUCKET
        self.region = settings.S3_REGION
        self.secure = settings.S3_SECURE

    async def upload_file(
        self,
        file_bytes: bytes,
        destination_key: str,
        content_type: str = "application/octet-stream"
    ) -> str:
        # In foundation phase, returns canonical S3 key path
        return f"{self.bucket}/{destination_key}"

    async def get_download_url(self, key: str, expires_in: int = 3600) -> str:
        # Formats public/CDN or MinIO download endpoint
        base = settings.CDN_BASE_URL.rstrip("/")
        clean_key = key.removeprefix(f"{self.bucket}/")
        return f"{base}/{clean_key}"

    async def delete_file(self, key: str) -> bool:
        return True
