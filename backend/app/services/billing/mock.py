import json
import uuid
from datetime import datetime, timedelta, timezone
from typing import Dict, List, Optional

from app.core.errors import AppException, ValidationError
from app.services.billing.base import BillingProvider
from app.services.billing.models import VerifiedTransaction, VerifiedWebhookPayload


class MockBillingProvider(BillingProvider):
    """
    Deterministic mock billing provider for automated testing and local development.
    Does not make external store network calls.
    """

    @property
    def provider_name(self) -> str:
        return "mock"

    async def verify_purchase(
        self,
        product_id: str,
        purchase_token: str,
        transaction_id: Optional[str] = None,
        original_transaction_id: Optional[str] = None,
    ) -> VerifiedTransaction:
        token = purchase_token.strip()

        if token in ["invalid", "forged", "error", ""]:
            raise ValidationError("Purchase token is invalid or could not be verified by store.")

        now = datetime.now(timezone.utc)
        clean_tx_id = transaction_id or f"mock_tx_{uuid.uuid4().hex[:12]}"
        clean_orig_tx_id = original_transaction_id or clean_tx_id

        # Determine interval duration
        is_yearly = "yearly" in product_id.lower() or "annual" in product_id.lower()
        duration_days = 365 if is_yearly else 30

        if token == "test_token_expired":
            return VerifiedTransaction(
                transaction_id=clean_tx_id,
                original_transaction_id=clean_orig_tx_id,
                product_id=product_id,
                purchase_date=now - timedelta(days=60),
                expires_date=now - timedelta(days=2),
                status="EXPIRED",
                environment="Sandbox",
                cancel_at_period_end=True,
                raw_payload=f'{{"mock_token": "{token}"}}',
            )
        elif token == "test_token_revoked":
            return VerifiedTransaction(
                transaction_id=clean_tx_id,
                original_transaction_id=clean_orig_tx_id,
                product_id=product_id,
                purchase_date=now - timedelta(days=10),
                expires_date=now + timedelta(days=20),
                status="REVOKED",
                environment="Sandbox",
                raw_payload=f'{{"mock_token": "{token}"}}',
            )
        elif token == "test_token_grace_period":
            return VerifiedTransaction(
                transaction_id=clean_tx_id,
                original_transaction_id=clean_orig_tx_id,
                product_id=product_id,
                purchase_date=now - timedelta(days=31),
                expires_date=now - timedelta(days=1),
                status="IN_GRACE_PERIOD",
                environment="Sandbox",
                grace_period_end=now + timedelta(days=15),
                raw_payload=f'{{"mock_token": "{token}"}}',
            )
        elif token == "test_token_canceled":
            return VerifiedTransaction(
                transaction_id=clean_tx_id,
                original_transaction_id=clean_orig_tx_id,
                product_id=product_id,
                purchase_date=now - timedelta(days=5),
                expires_date=now + timedelta(days=25),
                status="CANCELED",
                environment="Sandbox",
                cancel_at_period_end=True,
                raw_payload=f'{{"mock_token": "{token}"}}',
            )

        # Standard active purchase
        return VerifiedTransaction(
            transaction_id=clean_tx_id,
            original_transaction_id=clean_orig_tx_id,
            product_id=product_id,
            purchase_date=now,
            expires_date=now + timedelta(days=duration_days),
            status="ACTIVE",
            environment="Sandbox",
            cancel_at_period_end=False,
            raw_payload=f'{{"mock_token": "{token}", "product_id": "{product_id}"}}',
        )

    async def restore_purchases(
        self,
        receipt_data: Optional[str] = None,
        purchase_tokens: Optional[List[str]] = None,
    ) -> List[VerifiedTransaction]:
        tokens = purchase_tokens or ([receipt_data] if receipt_data else ["mock_restore_token"])
        results: List[VerifiedTransaction] = []
        for t in tokens:
            if not t or t == "invalid":
                continue
            tx = await self.verify_purchase(
                product_id="app.hums.premium.monthly",
                purchase_token=t,
            )
            results.append(tx)
        return results

    async def verify_webhook(
        self,
        headers: Dict[str, str],
        body: bytes,
    ) -> VerifiedWebhookPayload:
        try:
            payload = json.loads(body.decode("utf-8")) if body else {}
        except Exception:
            raise ValidationError("Malformed webhook JSON body")

        event_id = payload.get("event_id") or f"mock_evt_{uuid.uuid4().hex[:12]}"
        event_type = payload.get("event_type", "RENEWAL")
        product_id = payload.get("product_id", "app.hums.premium.monthly")
        now = datetime.now(timezone.utc)

        tx = VerifiedTransaction(
            transaction_id=payload.get("transaction_id", f"mock_tx_{uuid.uuid4().hex[:10]}"),
            original_transaction_id=payload.get("original_transaction_id"),
            product_id=product_id,
            purchase_date=now,
            expires_date=now + timedelta(days=30),
            status="ACTIVE" if event_type in ["RENEWAL", "INITIAL_BUY"] else "EXPIRED",
            environment="Sandbox",
            raw_payload=json.dumps(payload),
        )

        return VerifiedWebhookPayload(
            event_id=event_id,
            event_type=event_type,
            provider="mock",
            transaction=tx,
            original_transaction_id=payload.get("original_transaction_id"),
            raw_payload=body.decode("utf-8") if body else "",
        )
