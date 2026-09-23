from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from typing import Dict, List, Optional


@dataclass
class PushMessage:
    """Represents a push notification payload to be delivered across platforms."""

    title: str
    body: str
    data: Optional[Dict[str, str]] = None
    image_url: Optional[str] = None


@dataclass
class PushDeliveryResult:
    """Summary of batch or individual push delivery outcome."""

    success_count: int = 0
    failure_count: int = 0
    invalid_tokens: List[str] = field(default_factory=list)
    transient_error: bool = False
    error_details: Optional[str] = None


class PushProvider(ABC):
    """Abstract interface defining push notification provider contracts."""

    @abstractmethod
    async def send_to_token(self, token: str, message: PushMessage) -> bool:
        """Sends a notification to a single device token."""
        pass

    @abstractmethod
    async def send_multicast(
        self, tokens: List[str], message: PushMessage
    ) -> PushDeliveryResult:
        """
        Sends a notification to multiple device tokens simultaneously.
        Returns aggregate success/failure counts and identifies invalid tokens.
        """
        pass
