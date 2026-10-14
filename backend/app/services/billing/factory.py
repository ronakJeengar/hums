from functools import lru_cache
from app.core.config import get_settings
from app.services.billing.base import BillingProvider
from app.services.billing.apple import AppleBillingProvider
from app.services.billing.google import GooglePlayBillingProvider
from app.services.billing.mock import MockBillingProvider


class BillingProviderFactory:
    """Factory resolving appropriate billing provider instance based on platform."""

    def __init__(self):
        self.settings = get_settings()
        self._providers = {
            "apple": AppleBillingProvider(),
            "google": GooglePlayBillingProvider(),
            "mock": MockBillingProvider(),
            "test": MockBillingProvider(),
        }

    def get_provider(self, provider_name: str) -> BillingProvider:
        clean = provider_name.strip().lower()
        if clean in self._providers:
            return self._providers[clean]

        # In testing or development, fall back safely to mock
        if self.settings.APP_ENV != "production":
            return self._providers["mock"]

        raise ValueError(f"Unsupported billing provider: {provider_name}")


@lru_cache()
def get_billing_factory() -> BillingProviderFactory:
    return BillingProviderFactory()


def get_billing_provider(provider_name: str) -> BillingProvider:
    return get_billing_factory().get_provider(provider_name)
