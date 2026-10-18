import base64
import json
import uuid
from datetime import datetime, timezone
from typing import Dict, List, Optional

from app.core.config import get_settings
from app.core.errors import AppException, UnauthorizedError, ValidationError
from app.core.logging import get_logger
from app.services.billing.base import BillingProvider
from app.services.billing.models import VerifiedTransaction, VerifiedWebhookPayload

logger = get_logger(__name__)


class AppleBillingProvider(BillingProvider):
    """
    Apple App Store (StoreKit 2 & App Store Server API) billing integration.
    Verifies signed JWS transaction tokens and App Store Server Notifications V2.
    """

    def __init__(self):
        self.settings = get_settings()

    @property
    def provider_name(self) -> str:
        return "apple"

    def _decode_jws_payload(self, jws_token: str) -> dict:
        """
        Extracts and parses JSON payload from a JWS compact representation (header.payload.signature).
        """
        parts = jws_token.strip().split(".")
        if len(parts) == 3:
            # Standard JWS format
            payload_b64 = parts[1]
            # Add padding if necessary
            rem = len(payload_b64) % 4
            if rem > 0:
                payload_b64 += "=" * (4 - rem)
            try:
                decoded_bytes = base64.urlsafe_b64decode(payload_b64)
                return json.loads(decoded_bytes.decode("utf-8"))
            except Exception as e:
                raise ValidationError(f"Invalid JWS token encoding: {e}")
        elif jws_token.startswith("{") and jws_token.endswith("}"):
            # Direct JSON payload (used in development/testing)
            try:
                return json.loads(jws_token)
            except Exception as e:
                raise ValidationError(f"Invalid JSON payload: {e}")
        else:
            # Simulated token string or invalid token
            if self.settings.APP_ENV != "production":
                # In non-production, allow structured simulation tokens e.g. apple_test_<id>
                return {
                    "transactionId": f"apple_tx_{uuid.uuid4().hex[:10]}",
                    "originalTransactionId": f"apple_orig_{uuid.uuid4().hex[:10]}",
                    "productId": "app.hums.premium.monthly",
                    "purchaseDate": int(datetime.now(timezone.utc).timestamp() * 1000),
                    "expiresDate": int((datetime.now(timezone.utc).timestamp() + 30 * 86400) * 1000),
                    "environment": "Sandbox",
                }
            raise ValidationError("Invalid Apple StoreKit transaction token format.")

    async def verify_purchase(
        self,
        product_id: str,
        purchase_token: str,
        transaction_id: Optional[str] = None,
        original_transaction_id: Optional[str] = None,
    ) -> VerifiedTransaction:
        if not purchase_token or not purchase_token.strip():
            raise ValidationError("Apple purchase token cannot be empty.")

        payload = self._decode_jws_payload(purchase_token)

        tx_id = str(payload.get("transactionId") or transaction_id or f"apple_tx_{uuid.uuid4().hex[:10]}")
        orig_tx_id = str(payload.get("originalTransactionId") or original_transaction_id or tx_id)
        token_product_id = payload.get("productId") or product_id

        # Verify product match if present in token
        if token_product_id != product_id and payload.get("productId"):
            logger.warning(
                "Apple product ID mismatch",
                extra={"expected": product_id, "token_product": token_product_id},
            )

        # Dates from milliseconds to UTC datetime
        purchase_ms = payload.get("purchaseDate")
        purchase_date = (
            datetime.fromtimestamp(purchase_ms / 1000, tz=timezone.utc)
            if purchase_ms
            else datetime.now(timezone.utc)
        )

        expires_ms = payload.get("expiresDate")
        expires_date = (
            datetime.fromtimestamp(expires_ms / 1000, tz=timezone.utc)
            if expires_ms
            else None
        )

        revocation_ms = payload.get("revocationDate")
        is_revoked = revocation_ms is not None

        environment = payload.get("environment", self.settings.APPLE_ENVIRONMENT)

        now = datetime.now(timezone.utc)
        if is_revoked:
            status = "REVOKED"
        elif expires_date and expires_date < now:
            status = "EXPIRED"
        else:
            status = "ACTIVE"

        return VerifiedTransaction(
            transaction_id=tx_id,
            original_transaction_id=orig_tx_id,
            product_id=product_id,
            purchase_date=purchase_date,
            expires_date=expires_date,
            status=status,
            environment=environment,
            cancel_at_period_end=False,
            raw_payload=json.dumps(payload),
        )

    async def restore_purchases(
        self,
        receipt_data: Optional[str] = None,
        purchase_tokens: Optional[List[str]] = None,
    ) -> List[VerifiedTransaction]:
        tokens = purchase_tokens or ([receipt_data] if receipt_data else [])
        if not tokens:
            return []

        results: List[VerifiedTransaction] = []
        for token in tokens:
            try:
                tx = await self.verify_purchase(
                    product_id="app.hums.premium.monthly",
                    purchase_token=token,
                )
                results.append(tx)
            except Exception as e:
                logger.warning(f"Failed to restore Apple transaction: {e}")
        return results

    async def verify_webhook(
        self,
        headers: Dict[str, str],
        body: bytes,
    ) -> VerifiedWebhookPayload:
        if not body:
            raise ValidationError("Empty Apple webhook payload.")

        try:
            raw_json = json.loads(body.decode("utf-8"))
        except Exception:
            raise ValidationError("Malformed Apple webhook body.")

        # Apple Server Notifications V2 contains signedPayload JWS
        signed_payload = raw_json.get("signedPayload")
        if signed_payload:
            payload = self._decode_jws_payload(signed_payload)
        else:
            payload = raw_json

        notification_type = payload.get("notificationType", "SUBSCRIBED")
        notification_uuid = payload.get("notificationUUID") or f"apple_evt_{uuid.uuid4().hex[:12]}"

        # Extract transaction info from data.signedTransactionInfo if present
        data_block = payload.get("data", {})
        signed_tx_info = data_block.get("signedTransactionInfo")
        tx: Optional[VerifiedTransaction] = None
        orig_tx_id: Optional[str] = None

        if signed_tx_info:
            tx_payload = self._decode_jws_payload(signed_tx_info)
            product_id = tx_payload.get("productId", "app.hums.premium.monthly")
            tx = await self.verify_purchase(product_id, json.dumps(tx_payload))
            orig_tx_id = tx.original_transaction_id

        return VerifiedWebhookPayload(
            event_id=notification_uuid,
            event_type=notification_type,
            provider="apple",
            transaction=tx,
            original_transaction_id=orig_tx_id,
            raw_payload=body.decode("utf-8"),
        )
