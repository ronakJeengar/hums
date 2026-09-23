import logging
from typing import Any, Dict, List, Optional, Set

from app.services.push.base import PushDeliveryResult, PushMessage, PushProvider

logger = logging.getLogger("hums.services.push.mock")


class MockPushProvider(PushProvider):
    """
    In-memory mock push provider for local development, integration testing,
    and CI environments without external push credentials.
    """

    def __init__(
        self,
        invalid_tokens: Optional[Set[str]] = None,
        simulate_transient_error: bool = False,
    ):
        self.sent_messages: List[Dict[str, Any]] = []
        self.invalid_tokens: Set[str] = set(invalid_tokens or [])
        self.simulate_transient_error: bool = simulate_transient_error

    def clear(self) -> None:
        """Clears captured messages and simulated errors."""
        self.sent_messages.clear()
        self.invalid_tokens.clear()
        self.simulate_transient_error = False

    async def send_to_token(self, token: str, message: PushMessage) -> bool:
        if self.simulate_transient_error:
            raise ConnectionError("Simulated transient connection error in MockPushProvider")

        if token in self.invalid_tokens or token.startswith("invalid-") or token.startswith("unregistered-"):
            logger.info(f"[MockPushProvider] Token '{token}' is marked invalid/unregistered")
            return False

        self.sent_messages.append({
            "token": token,
            "title": message.title,
            "body": message.body,
            "data": message.data,
            "image_url": message.image_url,
        })
        logger.info(f"[MockPushProvider] Delivered message to token: {token[:12]}...")
        return True

    async def send_multicast(
        self, tokens: List[str], message: PushMessage
    ) -> PushDeliveryResult:
        if self.simulate_transient_error:
            return PushDeliveryResult(
                success_count=0,
                failure_count=len(tokens),
                invalid_tokens=[],
                transient_error=True,
                error_details="Simulated transient connection timeout",
            )

        success_count = 0
        failure_count = 0
        detected_invalid: List[str] = []

        for token in tokens:
            if token in self.invalid_tokens or token.startswith("invalid-") or token.startswith("unregistered-"):
                failure_count += 1
                detected_invalid.append(token)
            else:
                success_count += 1
                self.sent_messages.append({
                    "token": token,
                    "title": message.title,
                    "body": message.body,
                    "data": message.data,
                    "image_url": message.image_url,
                })

        logger.info(
            f"[MockPushProvider] Multicast result: {success_count} succeeded, "
            f"{failure_count} failed, {len(detected_invalid)} invalid"
        )
        return PushDeliveryResult(
            success_count=success_count,
            failure_count=failure_count,
            invalid_tokens=detected_invalid,
            transient_error=False,
        )
