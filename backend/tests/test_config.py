from app.core.config import Settings, get_settings


def test_settings_loading():
    """Validates that application settings load with appropriate defaults and types."""
    settings = get_settings()
    assert settings.APP_NAME == "Hums"
    assert settings.APP_PORT == 8001
    assert settings.ALGORITHM == "HS256"
    assert settings.ACCESS_TOKEN_EXPIRE_MINUTES > 0
    assert settings.REFRESH_TOKEN_EXPIRE_DAYS > 0
    assert "localhost" in settings.DATABASE_URL
    assert "redis" in settings.REDIS_URL
    assert isinstance(settings.CORS_ORIGINS, list)
