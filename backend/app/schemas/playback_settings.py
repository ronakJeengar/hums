from typing import Optional
from pydantic import BaseModel, ConfigDict, Field, field_validator


VALID_STREAMING_QUALITIES = {"AUTO", "LOW", "MEDIUM", "HIGH"}
VALID_NETWORK_QUALITIES = {"AUTO", "LOW", "MEDIUM", "HIGH"}
VALID_DOWNLOAD_QUALITIES = {"LOW", "MEDIUM", "HIGH"}


class PlaybackSettingsResponse(BaseModel):
    """User playback audio quality preferences and data saver mode."""
    streaming_quality: str = Field("AUTO", description="Default streaming quality tier: AUTO, LOW, MEDIUM, HIGH")
    mobile_data_quality: str = Field("LOW", description="Streaming quality on cellular/mobile data: LOW, MEDIUM, HIGH")
    wifi_quality: str = Field("HIGH", description="Streaming quality on Wi-Fi: AUTO, LOW, MEDIUM, HIGH")
    download_quality: str = Field("HIGH", description="Audio quality for offline downloads: LOW, MEDIUM, HIGH")
    data_saver_enabled: bool = Field(False, description="Whether Data Saver mode is active")

    model_config = ConfigDict(from_attributes=True)


class PlaybackSettingsUpdateRequest(BaseModel):
    """Payload for updating user playback audio quality settings."""
    streaming_quality: Optional[str] = Field(None, description="Streaming quality: AUTO, LOW, MEDIUM, HIGH")
    mobile_data_quality: Optional[str] = Field(None, description="Mobile quality: AUTO, LOW, MEDIUM, HIGH")
    wifi_quality: Optional[str] = Field(None, description="Wi-Fi quality: AUTO, LOW, MEDIUM, HIGH")
    download_quality: Optional[str] = Field(None, description="Download quality: LOW, MEDIUM, HIGH")
    data_saver_enabled: Optional[bool] = Field(None, description="Data Saver toggle")

    @field_validator("streaming_quality")
    @classmethod
    def validate_streaming_quality(cls, v: Optional[str]) -> Optional[str]:
        if v is not None:
            normalized = v.strip().upper()
            if normalized not in VALID_STREAMING_QUALITIES:
                raise ValueError(f"Invalid streaming_quality: '{v}'. Must be one of {sorted(VALID_STREAMING_QUALITIES)}")
            return normalized
        return v

    @field_validator("mobile_data_quality")
    @classmethod
    def validate_mobile_quality(cls, v: Optional[str]) -> Optional[str]:
        if v is not None:
            normalized = v.strip().upper()
            if normalized not in VALID_NETWORK_QUALITIES:
                raise ValueError(f"Invalid mobile_data_quality: '{v}'. Must be one of {sorted(VALID_NETWORK_QUALITIES)}")
            return normalized
        return v

    @field_validator("wifi_quality")
    @classmethod
    def validate_wifi_quality(cls, v: Optional[str]) -> Optional[str]:
        if v is not None:
            normalized = v.strip().upper()
            if normalized not in VALID_NETWORK_QUALITIES:
                raise ValueError(f"Invalid wifi_quality: '{v}'. Must be one of {sorted(VALID_NETWORK_QUALITIES)}")
            return normalized
        return v

    @field_validator("download_quality")
    @classmethod
    def validate_download_quality(cls, v: Optional[str]) -> Optional[str]:
        if v is not None:
            normalized = v.strip().upper()
            if normalized not in VALID_DOWNLOAD_QUALITIES:
                raise ValueError(f"Invalid download_quality: '{v}'. Must be one of {sorted(VALID_DOWNLOAD_QUALITIES)}")
            return normalized
        return v
