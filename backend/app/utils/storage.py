import asyncio
import logging
from abc import ABC, abstractmethod
from typing import Optional
import boto3
from botocore.config import Config
from app.core.config import get_settings

logger = logging.getLogger("hums.storage")
settings = get_settings()


class BaseStorageService(ABC):
    """Abstract interface for object storage operations."""

    @abstractmethod
    async def upload_file(
        self,
        file_bytes: bytes,
        destination_key: str,
        content_type: str = "application/octet-stream",
    ) -> str:
        """Uploads raw binary bytes to object storage and returns the object key/URL."""
        pass

    @abstractmethod
    async def upload_file_from_path(
        self,
        source_path: str,
        destination_key: str,
        content_type: str = "application/octet-stream",
    ) -> str:
        """Uploads a local file directly to object storage."""
        pass

    @abstractmethod
    async def download_file(self, key: str) -> bytes:
        """Downloads an object from storage and returns raw bytes."""
        pass

    @abstractmethod
    async def download_file_to_path(self, key: str, destination_path: str) -> None:
        """Downloads an object directly to a local filesystem destination path."""
        pass

    @abstractmethod
    async def get_download_url(self, key: str, expires_in: int = 3600) -> str:
        """Generates a secure download or public CDN access URL."""
        pass

    @abstractmethod
    async def delete_file(self, key: str) -> bool:
        """Deletes an object by key."""
        pass


class S3StorageService(BaseStorageService):
    """
    S3-compatible storage implementation supporting AWS S3, MinIO, and Cloudflare R2.
    Uses boto3 executed in thread pools to maintain non-blocking async execution.
    """

    def __init__(self):
        self.endpoint_url = settings.S3_ENDPOINT
        self.access_key = settings.S3_ACCESS_KEY
        self.secret_key = settings.S3_SECRET_KEY
        self.bucket = settings.S3_BUCKET
        self.region = settings.S3_REGION
        self.secure = settings.S3_SECURE

    def _get_client(self):
        """Creates an S3 client instance."""
        return boto3.client(
            "s3",
            endpoint_url=self.endpoint_url,
            aws_access_key_id=self.access_key,
            aws_secret_access_key=self.secret_key,
            region_name=self.region,
            config=Config(signature_version="s3v4"),
        )

    async def upload_file(
        self,
        file_bytes: bytes,
        destination_key: str,
        content_type: str = "application/octet-stream",
    ) -> str:
        clean_key = destination_key.removeprefix(f"{self.bucket}/").lstrip("/")

        def _upload():
            client = self._get_client()
            client.put_object(
                Bucket=self.bucket,
                Key=clean_key,
                Body=file_bytes,
                ContentType=content_type,
            )
            return clean_key

        try:
            return await asyncio.to_thread(_upload)
        except Exception as e:
            logger.error(f"Failed to upload object {clean_key} to bucket {self.bucket}: {e}")
            raise

    async def upload_file_from_path(
        self,
        source_path: str,
        destination_key: str,
        content_type: str = "application/octet-stream",
    ) -> str:
        clean_key = destination_key.removeprefix(f"{self.bucket}/").lstrip("/")

        def _upload_from_path():
            client = self._get_client()
            client.upload_file(
                Filename=source_path,
                Bucket=self.bucket,
                Key=clean_key,
                ExtraArgs={"ContentType": content_type},
            )
            return clean_key

        try:
            return await asyncio.to_thread(_upload_from_path)
        except Exception as e:
            logger.error(f"Failed to upload file {source_path} to {clean_key}: {e}")
            raise

    async def download_file(self, key: str) -> bytes:
        clean_key = key.removeprefix(f"{self.bucket}/").lstrip("/")

        def _download():
            client = self._get_client()
            response = client.get_object(Bucket=self.bucket, Key=clean_key)
            return response["Body"].read()

        try:
            return await asyncio.to_thread(_download)
        except Exception as e:
            logger.error(f"Failed to download object {clean_key} from bucket {self.bucket}: {e}")
            raise

    async def download_file_to_path(self, key: str, destination_path: str) -> None:
        clean_key = key.removeprefix(f"{self.bucket}/").lstrip("/")

        def _download_to_path():
            client = self._get_client()
            client.download_file(Bucket=self.bucket, Key=clean_key, Filename=destination_path)

        try:
            await asyncio.to_thread(_download_to_path)
        except Exception as e:
            logger.error(f"Failed to download object {clean_key} to {destination_path}: {e}")
            raise

    async def get_download_url(self, key: str, expires_in: int = 3600) -> str:
        base = settings.CDN_BASE_URL.rstrip("/")
        clean_key = key.removeprefix(f"{self.bucket}/").lstrip("/")
        return f"{base}/{clean_key}"

    async def delete_file(self, key: str) -> bool:
        clean_key = key.removeprefix(f"{self.bucket}/").lstrip("/")

        # Also strip full CDN_BASE_URL if passed
        base = settings.CDN_BASE_URL.rstrip("/")
        if clean_key.startswith(base):
            clean_key = clean_key.replace(base, "").lstrip("/")

        def _delete():
            client = self._get_client()
            client.delete_object(Bucket=self.bucket, Key=clean_key)
            return True

        try:
            return await asyncio.to_thread(_delete)
        except Exception as e:
            logger.warning(f"Failed to delete object {clean_key} from bucket {self.bucket}: {e}")
            return False
