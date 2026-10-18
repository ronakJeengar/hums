from abc import ABC, abstractmethod
from typing import Dict, List, Optional
from app.services.billing.models import VerifiedTransaction, VerifiedWebhookPayload


class BillingProvider(ABC):
    """Abstract interface defining platform purchase verification and webhook handling."""

    @property
    @abstractmethod
    def provider_name(self) -> str:
        """Name of the provider, e.g. 'apple', 'google', 'mock'."""
        pass

    @abstractmethod
    async def verify_purchase(
        self,
        product_id: str,
        purchase_token: str,
        transaction_id: Optional[str] = None,
        original_transaction_id: Optional[str] = None,
    ) -> VerifiedTransaction:
        """
        Validates purchase authenticity against the authoritative store platform.
        Raises AppException if token is forged, expired, or invalid.
        """
        pass

    @abstractmethod
    async def restore_purchases(
        self,
        receipt_data: Optional[str] = None,
        purchase_tokens: Optional[List[str]] = None,
    ) -> List[VerifiedTransaction]:
        """
        Restores valid prior subscriptions for a user from platform purchase history.
        """
        pass

    @abstractmethod
    async def verify_webhook(
        self,
        headers: Dict[str, str],
        body: bytes,
    ) -> VerifiedWebhookPayload:
        """
        Validates webhook signature authenticity and decodes subscription state event.
        Raises UnauthorizedError if signature is invalid.
        """
        pass
