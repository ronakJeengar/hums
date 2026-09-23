import logging
from typing import Optional

from app.core.config import get_settings
from app.services.push.base import PushDeliveryResult, PushMessage, PushProvider
from app.services.push.fcm import FCMPushProvider
from app.services.push.mock import MockPushProvider

logger = logging.getLogger("hums.services.push")

_provider_instance: Optional[PushProvider] = None


def get_push_provider() -> PushProvider:
    """
    Factory function returning the configured PushProvider instance.
    Defaults to MockPushProvider if settings.PUSH_PROVIDER is 'mock' or not 'fcm'.
    """
    global _provider_instance
    if _provider_instance is None:
        settings = get_settings()
        if settings.PUSH_PROVIDER.lower() == "fcm":
            logger.info("Initializing FCMPushProvider")
            _provider_instance = FCMPushProvider()
        else:
            logger.info("Initializing MockPushProvider")
            _provider_instance = MockPushProvider()
    return _provider_instance


def set_push_provider(provider: Optional[PushProvider]) -> None:
    """Allows test suites to override the global push provider instance."""
    global _provider_instance
    _provider_instance = provider


__all__ = [
    "PushProvider",
    "PushMessage",
    "PushDeliveryResult",
    "MockPushProvider",
    "FCMPushProvider",
    "get_push_provider",
    "set_push_provider",
]
