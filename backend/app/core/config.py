from functools import lru_cache
from typing import List, Union
from pydantic import Field, field_validator, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=True,
        extra="ignore"
    )

    # Application Settings
    APP_NAME: str = "Hums"
    APP_ENV: str = "development"
    APP_HOST: str = "0.0.0.0"
    APP_PORT: int = 8001
    DEBUG: bool = False
    LOG_LEVEL: str = "INFO"

    # Security & Rate Limiting
    RATE_LIMIT_ENABLED: bool = True

    # Security & JWT Tokens
    SECRET_KEY: str = "dev-secret-key-must-be-changed-in-production-min-32-chars"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7
    PASSWORD_RESET_TOKEN_EXPIRE_MINUTES: int = 15

    # Relational Database (PostgreSQL)
    DATABASE_URL: str = "postgresql+asyncpg://hums_user:hums_password@localhost:5434/hums_db"
    DATABASE_URL_SYNC: str = "postgresql://hums_user:hums_password@localhost:5434/hums_db"

    # Redis Cache & Message Broker
    REDIS_URL: str = "redis://localhost:6379/0"

    # Object Storage (S3 / MinIO)
    S3_ENDPOINT: str = "http://localhost:9000"
    S3_ACCESS_KEY: str = "minioadmin"
    S3_SECRET_KEY: str = "minioadmin"
    S3_BUCKET: str = "hums-audio"
    S3_REGION: str = "us-east-1"
    S3_SECURE: bool = False

    # CDN Base URL for media distribution
    CDN_BASE_URL: str = "http://localhost:9000/hums-audio"

    # Profile & Avatar Settings
    MAX_AVATAR_SIZE_MB: int = 5

    # Audio Upload Settings
    MAX_AUDIO_SIZE_MB: int = 100
    ALLOWED_AUDIO_MIME_TYPES: List[str] = [
        "audio/mpeg",
        "audio/mp3",
        "audio/wav",
        "audio/x-wav",
        "audio/wave",
        "audio/flac",
        "audio/x-flac",
        "audio/mp4",
        "audio/m4a",
        "audio/x-m4a",
        "audio/aac",
        "audio/ogg",
        "audio/vorbis",
    ]

    # Celery & Worker Settings
    CELERY_BROKER_URL: str = "redis://localhost:6379/1"
    CELERY_RESULT_BACKEND: str = "redis://localhost:6379/2"

    # Audio Transcoding & Processing Settings
    AUDIO_OUTPUT_FORMAT: str = "m4a"
    AUDIO_CODEC: str = "aac"
    AUDIO_BITRATE: str = "192k"
    WAVEFORM_SAMPLE_COUNT: int = 200
    FFMPEG_PATH: str = "ffmpeg"
    FFPROBE_PATH: str = "ffprobe"

    # Future AI Integration (Optional for foundation)
    GEMINI_API_KEY: str = ""

    # CORS Allowed Origins
    CORS_ORIGINS: Union[List[str], str] = ["http://localhost:3000", "http://localhost:8000", "http://127.0.0.1:8000"]

    @field_validator("CORS_ORIGINS", mode="before")
    @classmethod
    def assemble_cors_origins(cls, v: Union[str, List[str]]) -> List[str]:
        if isinstance(v, str) and not v.startswith("["):
            return [i.strip() for i in v.split(",") if i.strip()]
        elif isinstance(v, (list, str)):
            return v
        raise ValueError(v)

    @model_validator(mode="after")
    def validate_production_settings(self) -> "Settings":
        if self.APP_ENV.lower() == "production":
            insecure_defaults = [
                "dev-secret-key-must-be-changed-in-production-min-32-chars",
                "change-this-insecure-secret-key-for-development-only-min-32-chars",
                "secret",
                "password",
            ]
            if self.SECRET_KEY in insecure_defaults or len(self.SECRET_KEY) < 32:
                raise ValueError("SECRET_KEY must be securely configured with at least 32 characters in production.")
            if self.DEBUG:
                raise ValueError("DEBUG must be False in production.")
            if any(origin == "*" for origin in self.CORS_ORIGINS):
                raise ValueError("Wildcard '*' CORS origins are forbidden in production.")
        return self


@lru_cache()
def get_settings() -> Settings:
    """Returns cached instance of the application settings."""
    return Settings()
