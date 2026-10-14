import json
import time
import uuid
from datetime import datetime, timezone
from typing import Dict, List, Optional

import redis.asyncio as aioredis
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.errors import (
    AppException,
    ConflictError,
    NotFoundError,
    UnauthorizedError,
    ValidationError,
)
from app.core.logging import get_logger
from app.core.metrics import metrics_registry
from app.db.models.subscription import SubscriptionPlan, UserSubscription
from app.repositories.subscription_repository import SubscriptionRepository
from app.schemas.subscription import (
    PurchaseRestoreRequest,
    PurchaseRestoreResponse,
    PurchaseVerificationRequest,
    PurchaseVerificationResponse,
    SubscriptionPlanResponse,
    UserSubscriptionResponse,
    WebhookEventResponse,
)
from app.services.billing.base import BillingProvider
from app.services.billing.factory import get_billing_provider
from app.services.billing.models import VerifiedTransaction
from app.services.entitlement_service import EntitlementService

logger = get_logger(__name__)


class SubscriptionService:
    """
    Orchestrates commercial subscription operations, authoritative purchase verification,
    restore flows, and provider webhook processing.
    """

    def __init__(
        self,
        db_session: AsyncSession,
        redis_client: Optional[aioredis.Redis] = None,
    ):
        self.session = db_session
        self.redis = redis_client
        self.repo = SubscriptionRepository(db_session)
        self.entitlement_service = EntitlementService(db_session, redis_client)
        self.settings = get_settings()

    async def list_plans(self) -> List[SubscriptionPlanResponse]:
        """Returns catalog of active plans formatted for mobile client paywalls."""
        plans = await self.repo.list_active_plans()
        responses: List[SubscriptionPlanResponse] = []
        for p in plans:
            entitlements = [
                pe.entitlement.code
                for pe in (p.plan_entitlements or [])
                if pe.entitlement
            ]
            responses.append(
                SubscriptionPlanResponse(
                    id=p.id,
                    code=p.code,
                    name=p.name,
                    description=p.description,
                    billing_interval=p.billing_interval,
                    price_cents=p.price_cents,
                    currency=p.currency,
                    apple_product_id=p.apple_product_id,
                    google_product_id=p.google_product_id,
                    is_active=p.is_active,
                    display_order=p.display_order,
                    entitlements=entitlements,
                )
            )
        return responses

    def _to_user_sub_response(
        self, sub: UserSubscription, active_entitlements: List[str]
    ) -> UserSubscriptionResponse:
        now = datetime.now(timezone.utc)
        is_active = (
            sub.status in ["ACTIVE", "IN_GRACE_PERIOD", "CANCELED"]
            and (
                sub.current_period_end > now
                or (sub.grace_period_end is not None and sub.grace_period_end > now)
            )
        )
        return UserSubscriptionResponse(
            id=sub.id,
            user_id=sub.user_id,
            plan_code=sub.plan.code if sub.plan else "UNKNOWN",
            plan_name=sub.plan.name if sub.plan else "Unknown Plan",
            provider=sub.provider,
            provider_subscription_id=sub.provider_subscription_id,
            provider_product_id=sub.provider_product_id,
            status=sub.status,
            is_active=is_active,
            current_period_start=sub.current_period_start,
            current_period_end=sub.current_period_end,
            cancel_at_period_end=sub.cancel_at_period_end,
            grace_period_end=sub.grace_period_end,
            active_entitlements=active_entitlements,
        )

    async def get_user_subscription(
        self, user_id: uuid.UUID
    ) -> Optional[UserSubscriptionResponse]:
        """Retrieves user's active subscription, or latest if inactive."""
        sub = await self.repo.get_active_subscription(user_id)
        if not sub:
            sub = await self.repo.get_latest_subscription(user_id)
        if not sub:
            return None

        entitlements = list(await self.entitlement_service.get_user_entitlements(user_id))
        return self._to_user_sub_response(sub, entitlements)

    async def verify_purchase(
        self,
        user_id: uuid.UUID,
        request: PurchaseVerificationRequest,
    ) -> PurchaseVerificationResponse:
        """
        Authoritatively verifies store purchase token against platform billing provider.
        Enforces idempotency, prevents transaction replay attacks, and grants entitlements.
        """
        start_time = time.time()
        provider_name = request.provider.lower().strip()
        billing_provider: BillingProvider = get_billing_provider(provider_name)

        # 1. Resolve matching subscription plan
        plan = await self.repo.get_plan_by_product_id(provider_name, request.product_id)
        if not plan:
            # Fallback by code if product ID directly matches plan code
            plan = await self.repo.get_plan_by_code(request.product_id)
        if not plan:
            raise ValidationError(
                f"Unknown or unconfigured subscription product ID: {request.product_id}",
                code="INVALID_PRODUCT_ID",
            )

        # 2. Authoritative verification with platform provider
        try:
            verified_tx: VerifiedTransaction = await billing_provider.verify_purchase(
                product_id=request.product_id,
                purchase_token=request.purchase_token,
                transaction_id=request.transaction_id,
                original_transaction_id=request.original_transaction_id,
            )
        except Exception as e:
            elapsed = time.time() - start_time
            metrics_registry.record_subscription_verification(provider_name, "FAILED", elapsed)
            logger.error(f"Provider purchase verification failed: {e}")
            raise ValidationError(f"Purchase could not be verified by {provider_name}: {e}")

        elapsed = time.time() - start_time
        metrics_registry.record_subscription_verification(
            provider_name, verified_tx.status, elapsed
        )

        # 3. Idempotency & Replay Protection: Check if transaction was already processed
        existing_tx = await self.repo.get_transaction(
            provider=provider_name,
            transaction_id=verified_tx.transaction_id,
        )

        if existing_tx:
            if existing_tx.user_id == user_id:
                # Idempotent replay by original purchaser: return current state
                current_sub = await self.repo.get_active_subscription(user_id)
                if current_sub:
                    entitlements = list(
                        await self.entitlement_service.get_user_entitlements(user_id)
                    )
                    return PurchaseVerificationResponse(
                        subscription=self._to_user_sub_response(current_sub, entitlements),
                        entitlements=entitlements,
                        message="Purchase already verified.",
                    )
            else:
                # Security Rule: Cross-account transaction reuse attempt
                logger.warning(
                    "Cross-account transaction replay detected",
                    extra={
                        "original_user_id": str(existing_tx.user_id),
                        "attempting_user_id": str(user_id),
                        "transaction_id": verified_tx.transaction_id,
                    },
                )
                raise ConflictError(
                    "This purchase transaction has already been linked to another user account.",
                    code="TRANSACTION_ALREADY_LINKED",
                )

        now = datetime.now(timezone.utc)
        period_start = verified_tx.purchase_date
        period_end = verified_tx.expires_date or (period_start + (
            (datetime.now(timezone.utc) - datetime.now(timezone.utc))  # dummy
            if False else (
                datetime.fromtimestamp(period_start.timestamp() + 365 * 86400, tz=timezone.utc)
                if plan.billing_interval == "YEAR"
                else datetime.fromtimestamp(period_start.timestamp() + 30 * 86400, tz=timezone.utc)
            )
        ))

        # 4. Check for existing subscription to renew or create a new one
        existing_sub = None
        if verified_tx.original_transaction_id:
            existing_sub = await self.repo.get_subscription_by_original_tx(
                provider=provider_name,
                original_transaction_id=verified_tx.original_transaction_id,
            )
        if not existing_sub:
            existing_sub = await self.repo.get_active_subscription(user_id)

        if existing_sub and existing_sub.user_id == user_id:
            # Renew existing subscription
            subscription = await self.repo.update_subscription_status(
                subscription_id=existing_sub.id,
                status=verified_tx.status,
                current_period_end=period_end,
                cancel_at_period_end=verified_tx.cancel_at_period_end,
                grace_period_end=verified_tx.grace_period_end,
                latest_transaction_id=verified_tx.transaction_id,
            )
        else:
            # Create new user subscription
            subscription = await self.repo.create_user_subscription(
                user_id=user_id,
                plan_id=plan.id,
                provider=provider_name,
                current_period_start=period_start,
                current_period_end=period_end,
                status=verified_tx.status,
                provider_product_id=request.product_id,
                original_transaction_id=verified_tx.original_transaction_id or verified_tx.transaction_id,
                latest_transaction_id=verified_tx.transaction_id,
                cancel_at_period_end=verified_tx.cancel_at_period_end,
                grace_period_end=verified_tx.grace_period_end,
            )

        # 5. Record verified transaction in ledger
        await self.repo.record_transaction(
            user_id=user_id,
            subscription_id=subscription.id,
            provider=provider_name,
            transaction_id=verified_tx.transaction_id,
            original_transaction_id=verified_tx.original_transaction_id,
            product_id=request.product_id,
            purchase_date=verified_tx.purchase_date,
            expires_date=period_end,
            environment=verified_tx.environment,
            raw_payload=verified_tx.raw_payload or request.purchase_token,
        )

        # 6. Grant entitlements if active or in grace period
        if verified_tx.status in ["ACTIVE", "IN_GRACE_PERIOD"]:
            await self.repo.grant_plan_entitlements(
                user_id=user_id,
                plan_id=plan.id,
                source_subscription_id=subscription.id,
                effective_start=period_start,
                effective_end=period_end,
            )
            for pe in (plan.plan_entitlements or []):
                if pe.entitlement:
                    metrics_registry.entitlement_grants_total.inc(entitlement=pe.entitlement.code)

        # 7. Invalidate Redis entitlement cache
        await self.entitlement_service.invalidate_user_entitlements(user_id)

        # Commit transaction
        await self.session.commit()

        # Reload subscription with eager relationships
        updated_sub = await self.repo.get_by_id(subscription.id)
        entitlements = list(await self.entitlement_service.get_user_entitlements(user_id))

        return PurchaseVerificationResponse(
            subscription=self._to_user_sub_response(updated_sub, entitlements),
            entitlements=entitlements,
            message="Purchase successfully verified and premium entitlements granted.",
        )

    async def restore_purchases(
        self,
        user_id: uuid.UUID,
        request: PurchaseRestoreRequest,
    ) -> PurchaseRestoreResponse:
        """Restores previous store purchases for this user."""
        provider_name = request.provider.lower().strip()
        billing_provider: BillingProvider = get_billing_provider(provider_name)

        try:
            restored_txs: List[VerifiedTransaction] = await billing_provider.restore_purchases(
                receipt_data=request.receipt_data,
                purchase_tokens=request.purchase_tokens,
            )
        except Exception as e:
            logger.error(f"Purchase restore provider error: {e}")
            raise ValidationError(f"Could not restore purchases from {provider_name}: {e}")

        restored_count = 0
        latest_active_sub = None

        for tx in restored_txs:
            # Check for existing transaction
            existing_tx = await self.repo.get_transaction(provider_name, tx.transaction_id)
            if existing_tx and existing_tx.user_id != user_id:
                logger.warning(
                    f"Skipping restore for transaction {tx.transaction_id}: already owned by another account."
                )
                continue

            plan = await self.repo.get_plan_by_product_id(provider_name, tx.product_id)
            if not plan:
                continue

            # Verify or link to user
            sub_req = PurchaseVerificationRequest(
                provider=provider_name,
                product_id=tx.product_id,
                purchase_token=tx.raw_payload or tx.transaction_id,
                transaction_id=tx.transaction_id,
                original_transaction_id=tx.original_transaction_id,
            )
            try:
                res = await self.verify_purchase(user_id, sub_req)
                restored_count += 1
                latest_active_sub = res.subscription
            except Exception as e:
                logger.info(f"Restore item verification skipped: {e}")

        metrics_registry.record_subscription_restore(
            provider_name, "success" if restored_count > 0 else "empty"
        )

        active_entitlements = list(await self.entitlement_service.get_user_entitlements(user_id))
        msg = (
            f"Successfully restored {restored_count} purchase(s)."
            if restored_count > 0
            else "No active purchases found to restore."
        )

        return PurchaseRestoreResponse(
            restored=restored_count > 0,
            active_subscription=latest_active_sub,
            active_entitlements=active_entitlements,
            restored_count=restored_count,
            message=msg,
        )

    async def handle_webhook(
        self,
        provider_name: str,
        headers: Dict[str, str],
        body: bytes,
    ) -> WebhookEventResponse:
        """
        Processes provider lifecycle notifications (renewals, cancellations, refunds, grace periods).
        Deduplicates events and reconciles subscription state asynchronously or immediately.
        """
        clean_provider = provider_name.lower().strip()
        provider = get_billing_provider(clean_provider)

        # 1. Authenticate webhook signature and decode payload
        payload = await provider.verify_webhook(headers, body)

        # 2. Deduplicate event
        existing_event = await self.repo.get_webhook_event(
            clean_provider, payload.event_id
        )
        if existing_event:
            metrics_registry.record_subscription_webhook_duplicate(clean_provider)
            logger.info(
                "Duplicate webhook event received",
                extra={"provider": clean_provider, "event_id": payload.event_id},
            )
            return WebhookEventResponse(
                received=True,
                event_id=payload.event_id,
                status="DUPLICATE",
            )

        # 3. Record event as RECEIVED
        event_record = await self.repo.record_webhook_event(
            provider=clean_provider,
            provider_event_id=payload.event_id,
            event_type=payload.event_type,
            raw_payload=payload.raw_payload,
        )

        # 4. Reconcile subscription state
        try:
            if payload.transaction and payload.original_transaction_id:
                sub = await self.repo.get_subscription_by_original_tx(
                    clean_provider, payload.original_transaction_id
                )
                if sub:
                    new_status = payload.transaction.status
                    await self.repo.update_subscription_status(
                        subscription_id=sub.id,
                        status=new_status,
                        current_period_end=payload.transaction.expires_date,
                        grace_period_end=payload.transaction.grace_period_end,
                        latest_transaction_id=payload.transaction.transaction_id,
                    )

                    if new_status in ["REVOKED", "EXPIRED"]:
                        await self.repo.revoke_subscription_entitlements(
                            subscription_id=sub.id,
                            reason=f"Provider webhook event: {payload.event_type}",
                        )

                    # Invalidate cache
                    await self.entitlement_service.invalidate_user_entitlements(sub.user_id)

            await self.repo.update_webhook_event_status(event_record.id, "PROCESSED")
            await self.session.commit()
            metrics_registry.record_subscription_webhook(clean_provider, "PROCESSED")
            return WebhookEventResponse(
                received=True,
                event_id=payload.event_id,
                status="PROCESSED",
            )
        except Exception as e:
            await self.repo.update_webhook_event_status(
                event_record.id, "FAILED", error_message=str(e)
            )
            await self.session.commit()
            metrics_registry.record_subscription_webhook(clean_provider, "FAILED")
            logger.error(f"Error processing webhook event {payload.event_id}: {e}")
            return WebhookEventResponse(
                received=True,
                event_id=payload.event_id,
                status="FAILED",
            )
