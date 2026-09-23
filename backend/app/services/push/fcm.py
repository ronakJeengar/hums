import asyncio
import logging
import os
from typing import List, Optional

import firebase_admin
from firebase_admin import credentials, messaging
from firebase_admin.exceptions import FirebaseError

from app.core.config import get_settings
from app.services.push.base import PushDeliveryResult, PushMessage, PushProvider

logger = logging.getLogger("hums.services.push.fcm")


class FCMPushProvider(PushProvider):
    """
    Production push notification provider using Firebase Cloud Messaging (FCM).
    Delivers messages to Android, iOS, and Web clients through the Firebase Admin SDK.
    """

    def __init__(self, credentials_path: Optional[str] = None):
        settings = get_settings()
        self.creds_path = credentials_path or settings.FIREBASE_CREDENTIALS_PATH
        self.project_id = settings.FIREBASE_PROJECT_ID
        self._initialized = False
        self._init_firebase()

    def _init_firebase(self) -> None:
        """Initializes the Firebase Admin SDK if not already initialized."""
        try:
            # Check if default app is already initialized
            firebase_admin.get_app()
            self._initialized = True
        except ValueError:
            # No default app exists, attempt to initialize
            try:
                if self.creds_path and os.path.exists(self.creds_path):
                    cred = credentials.Certificate(self.creds_path)
                    firebase_admin.initialize_app(cred, {"projectId": self.project_id} if self.project_id else None)
                    logger.info(f"Firebase Admin initialized with certificate: {self.creds_path}")
                    self._initialized = True
                elif "GOOGLE_APPLICATION_CREDENTIALS" in os.environ:
                    cred = credentials.ApplicationDefault()
                    firebase_admin.initialize_app(cred, {"projectId": self.project_id} if self.project_id else None)
                    logger.info("Firebase Admin initialized with Application Default Credentials")
                    self._initialized = True
                else:
                    logger.warning(
                        "Firebase credentials not provided. FCMPushProvider will log operations in dry-run mode."
                    )
                    self._initialized = False
            except Exception as e:
                logger.error(f"Failed to initialize Firebase Admin SDK: {e}")
                self._initialized = False

    def _build_multicast_message(
        self, tokens: List[str], message: PushMessage
    ) -> messaging.MulticastMessage:
        """Builds a formatted FCM MulticastMessage targeting mobile platforms."""
        str_data = {str(k): str(v) for k, v in (message.data or {}).items()}

        notification = messaging.Notification(
            title=message.title,
            body=message.body,
            image=message.image_url,
        )

        android_config = messaging.AndroidConfig(
            priority="high",
            notification=messaging.AndroidNotification(
                sound="default",
                channel_id="hums_general_channel",
                click_action="FLUTTER_NOTIFICATION_CLICK",
            ),
        )

        apns_config = messaging.ApnsConfig(
            payload=messaging.Payload(
                aps=messaging.Aps(
                    sound="default",
                    badge=1,
                    content_available=True,
                )
            )
        )

        return messaging.MulticastMessage(
            tokens=tokens,
            notification=notification,
            data=str_data,
            android=android_config,
            apns=apns_config,
        )

    def _send_multicast_sync(
        self, tokens: List[str], message: PushMessage
    ) -> PushDeliveryResult:
        if not self._initialized:
            logger.warning("FCM not initialized: simulating multicast delivery")
            return PushDeliveryResult(
                success_count=len(tokens),
                failure_count=0,
                invalid_tokens=[],
            )

        multicast_msg = self._build_multicast_message(tokens, message)
        try:
            batch_response = messaging.send_each_for_multicast(multicast_msg)
        except Exception as exc:
            logger.error(f"FCM multicast batch request failed: {exc}", exc_info=True)
            is_transient = any(
                w in str(exc).lower() for w in ["unavailable", "timeout", "network", "internal", "quota"]
            )
            return PushDeliveryResult(
                success_count=0,
                failure_count=len(tokens),
                invalid_tokens=[],
                transient_error=is_transient,
                error_details=str(exc),
            )

        invalid_tokens: List[str] = []
        has_transient_error = False

        for idx, resp in enumerate(batch_response.responses):
            if not resp.success:
                exc = resp.exception
                error_code = getattr(exc, "code", "")
                token = tokens[idx]
                logger.warning(f"Failed to deliver FCM push to {token[:12]}...: {exc} (code={error_code})")

                # Detect invalid/unregistered tokens for automatic pruning
                if isinstance(exc, (messaging.UnregisteredError, messaging.SenderIdMismatchError)):
                    invalid_tokens.append(token)
                elif "registration-token-not-registered" in str(exc).lower() or "invalid-argument" in str(exc).lower():
                    invalid_tokens.append(token)
                elif isinstance(exc, messaging.UnavailableError) or "unavailable" in str(exc).lower():
                    has_transient_error = True

        return PushDeliveryResult(
            success_count=batch_response.success_count,
            failure_count=batch_response.failure_count,
            invalid_tokens=invalid_tokens,
            transient_error=has_transient_error,
        )

    async def send_to_token(self, token: str, message: PushMessage) -> bool:
        result = await self.send_multicast([token], message)
        return result.success_count > 0

    async def send_multicast(
        self, tokens: List[str], message: PushMessage
    ) -> PushDeliveryResult:
        if not tokens:
            return PushDeliveryResult()

        # Run blocking Firebase I/O in threadpool
        return await asyncio.to_thread(self._send_multicast_sync, tokens, message)
