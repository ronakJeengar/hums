import hashlib
import uuid
from datetime import datetime, timezone
from typing import List, Optional, Set
from sqlalchemy import and_, or_, select, update
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.db.models.subscription import (
    Entitlement,
    PlanEntitlement,
    SubscriptionPlan,
    SubscriptionTransaction,
    SubscriptionWebhookEvent,
    UserEntitlementGrant,
    UserSubscription,
)
from app.repositories.base import BaseRepository


class SubscriptionRepository(BaseRepository[UserSubscription]):
    """Repository handling database operations for plans, subscriptions, and entitlements."""

    def __init__(self, session: AsyncSession):
        super().__init__(UserSubscription, session)

    async def list_active_plans(self) -> List[SubscriptionPlan]:
        """Returns all active plans ordered by display_order with entitlements eagerly loaded."""
        stmt = (
            select(SubscriptionPlan)
            .where(SubscriptionPlan.is_active == True)
            .options(
                selectinload(SubscriptionPlan.plan_entitlements).selectinload(
                    PlanEntitlement.entitlement
                )
            )
            .order_by(SubscriptionPlan.display_order.asc())
        )
        result = await self.session.execute(stmt)
        return list(result.scalars().all())

    async def get_plan_by_code(self, code: str) -> Optional[SubscriptionPlan]:
        """Retrieves a plan by its unique code (e.g., FREE, PREMIUM_MONTHLY, PREMIUM_YEARLY)."""
        stmt = (
            select(SubscriptionPlan)
            .where(SubscriptionPlan.code == code)
            .options(
                selectinload(SubscriptionPlan.plan_entitlements).selectinload(
                    PlanEntitlement.entitlement
                )
            )
        )
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_plan_by_product_id(
        self, provider: str, product_id: str
    ) -> Optional[SubscriptionPlan]:
        """Resolves a plan from a provider-specific store product identifier."""
        clean_provider = provider.lower()
        clean_product_id = product_id.strip()

        if clean_provider == "apple":
            condition = SubscriptionPlan.apple_product_id == clean_product_id
        elif clean_provider == "google":
            condition = SubscriptionPlan.google_product_id == clean_product_id
        else:
            condition = or_(
                SubscriptionPlan.apple_product_id == clean_product_id,
                SubscriptionPlan.google_product_id == clean_product_id,
                SubscriptionPlan.code == clean_product_id,
            )

        stmt = (
            select(SubscriptionPlan)
            .where(and_(SubscriptionPlan.is_active == True, condition))
            .options(
                selectinload(SubscriptionPlan.plan_entitlements).selectinload(
                    PlanEntitlement.entitlement
                )
            )
        )
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_active_subscription(
        self, user_id: uuid.UUID
    ) -> Optional[UserSubscription]:
        """
        Retrieves user's currently active subscription.
        Considers ACTIVE, IN_GRACE_PERIOD, and CANCELED states with valid end dates.
        """
        now = datetime.now(timezone.utc)
        stmt = (
            select(UserSubscription)
            .where(
                and_(
                    UserSubscription.user_id == user_id,
                    UserSubscription.status.in_(["ACTIVE", "IN_GRACE_PERIOD", "CANCELED"]),
                    or_(
                        UserSubscription.current_period_end > now,
                        and_(
                            UserSubscription.grace_period_end.is_not(None),
                            UserSubscription.grace_period_end > now,
                        ),
                    ),
                )
            )
            .options(
                selectinload(UserSubscription.plan).selectinload(
                    SubscriptionPlan.plan_entitlements
                ).selectinload(PlanEntitlement.entitlement)
            )
            .order_by(UserSubscription.current_period_end.desc())
            .limit(1)
        )
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_latest_subscription(
        self, user_id: uuid.UUID
    ) -> Optional[UserSubscription]:
        """Retrieves user's most recent subscription regardless of status."""
        stmt = (
            select(UserSubscription)
            .where(UserSubscription.user_id == user_id)
            .options(
                selectinload(UserSubscription.plan).selectinload(
                    SubscriptionPlan.plan_entitlements
                ).selectinload(PlanEntitlement.entitlement)
            )
            .order_by(UserSubscription.created_at.desc())
            .limit(1)
        )
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_subscription_by_original_tx(
        self, provider: str, original_transaction_id: str
    ) -> Optional[UserSubscription]:
        """Finds existing subscription by original store transaction ID."""
        stmt = (
            select(UserSubscription)
            .where(
                and_(
                    UserSubscription.provider == provider,
                    UserSubscription.original_transaction_id == original_transaction_id,
                )
            )
            .options(selectinload(UserSubscription.plan))
            .order_by(UserSubscription.current_period_end.desc())
            .limit(1)
        )
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def create_user_subscription(
        self,
        user_id: uuid.UUID,
        plan_id: uuid.UUID,
        provider: str,
        current_period_start: datetime,
        current_period_end: datetime,
        status: str = "ACTIVE",
        provider_subscription_id: Optional[str] = None,
        provider_product_id: Optional[str] = None,
        original_transaction_id: Optional[str] = None,
        latest_transaction_id: Optional[str] = None,
        cancel_at_period_end: bool = False,
        grace_period_end: Optional[datetime] = None,
    ) -> UserSubscription:
        """Persists a new user subscription relationship."""
        sub = UserSubscription(
            user_id=user_id,
            plan_id=plan_id,
            provider=provider,
            provider_subscription_id=provider_subscription_id,
            provider_product_id=provider_product_id,
            original_transaction_id=original_transaction_id,
            latest_transaction_id=latest_transaction_id,
            status=status,
            current_period_start=current_period_start,
            current_period_end=current_period_end,
            cancel_at_period_end=cancel_at_period_end,
            grace_period_end=grace_period_end,
        )
        self.session.add(sub)
        await self.session.flush()
        await self.session.refresh(sub)
        return sub

    async def update_subscription_status(
        self,
        subscription_id: uuid.UUID,
        status: str,
        current_period_end: Optional[datetime] = None,
        cancel_at_period_end: Optional[bool] = None,
        grace_period_end: Optional[datetime] = None,
        canceled_at: Optional[datetime] = None,
        latest_transaction_id: Optional[str] = None,
    ) -> Optional[UserSubscription]:
        """Updates subscription status and period metadata."""
        sub = await self.get_by_id(subscription_id)
        if not sub:
            return None

        sub.status = status
        if current_period_end is not None:
            sub.current_period_end = current_period_end
        if cancel_at_period_end is not None:
            sub.cancel_at_period_end = cancel_at_period_end
        if grace_period_end is not None:
            sub.grace_period_end = grace_period_end
        if canceled_at is not None:
            sub.canceled_at = canceled_at
        if latest_transaction_id is not None:
            sub.latest_transaction_id = latest_transaction_id

        await self.session.flush()
        await self.session.refresh(sub)
        return sub

    async def get_active_entitlement_codes(self, user_id: uuid.UUID) -> Set[str]:
        """
        Calculates all authoritative active entitlement codes for a user.
        Combines:
        1. Entitlements granted by active UserSubscriptions.
        2. Direct active UserEntitlementGrants within valid effective date windows.
        """
        now = datetime.now(timezone.utc)
        entitlements: Set[str] = set()

        # 1. From active subscriptions
        active_sub = await self.get_active_subscription(user_id)
        if active_sub and active_sub.plan and active_sub.plan.plan_entitlements:
            for pe in active_sub.plan.plan_entitlements:
                if pe.entitlement:
                    entitlements.add(pe.entitlement.code)

        # 2. From direct grants
        stmt = (
            select(Entitlement.code)
            .join(UserEntitlementGrant, UserEntitlementGrant.entitlement_id == Entitlement.id)
            .where(
                and_(
                    UserEntitlementGrant.user_id == user_id,
                    UserEntitlementGrant.is_active == True,
                    UserEntitlementGrant.effective_start <= now,
                    or_(
                        UserEntitlementGrant.effective_end.is_(None),
                        UserEntitlementGrant.effective_end > now,
                    ),
                    UserEntitlementGrant.revoked_at.is_(None),
                )
            )
        )
        result = await self.session.execute(stmt)
        for code in result.scalars().all():
            entitlements.add(code)

        return entitlements

    async def grant_plan_entitlements(
        self,
        user_id: uuid.UUID,
        plan_id: uuid.UUID,
        source_subscription_id: uuid.UUID,
        effective_start: datetime,
        effective_end: datetime,
    ) -> List[UserEntitlementGrant]:
        """Creates or refreshes entitlement grants derived from a subscribed plan."""
        stmt = (
            select(PlanEntitlement)
            .where(PlanEntitlement.plan_id == plan_id)
            .options(selectinload(PlanEntitlement.entitlement))
        )
        result = await self.session.execute(stmt)
        plan_entitlements = result.scalars().all()

        grants: List[UserEntitlementGrant] = []
        for pe in plan_entitlements:
            grant = UserEntitlementGrant(
                user_id=user_id,
                entitlement_id=pe.entitlement_id,
                source_subscription_id=source_subscription_id,
                is_active=True,
                effective_start=effective_start,
                effective_end=effective_end,
            )
            self.session.add(grant)
            grants.append(grant)

        await self.session.flush()
        return grants

    async def revoke_subscription_entitlements(
        self, subscription_id: uuid.UUID, reason: str = "Subscription expired or revoked"
    ) -> int:
        """Deactivates and revokes all entitlement grants tied to a subscription."""
        now = datetime.now(timezone.utc)
        stmt = (
            update(UserEntitlementGrant)
            .where(
                and_(
                    UserEntitlementGrant.source_subscription_id == subscription_id,
                    UserEntitlementGrant.is_active == True,
                )
            )
            .values(
                is_active=False,
                revoked_at=now,
                revocation_reason=reason,
            )
        )
        result = await self.session.execute(stmt)
        await self.session.flush()
        return result.rowcount

    # -------------------------------------------------------------------------
    # Transaction Ledger & Replay Prevention
    # -------------------------------------------------------------------------
    async def get_transaction(
        self, provider: str, transaction_id: str
    ) -> Optional[SubscriptionTransaction]:
        """Queries verified transaction to check for replay or cross-account reuse."""
        stmt = select(SubscriptionTransaction).where(
            and_(
                SubscriptionTransaction.provider == provider,
                SubscriptionTransaction.transaction_id == transaction_id,
            )
        )
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def record_transaction(
        self,
        user_id: uuid.UUID,
        provider: str,
        transaction_id: str,
        product_id: str,
        purchase_date: datetime,
        raw_payload: str,
        subscription_id: Optional[uuid.UUID] = None,
        original_transaction_id: Optional[str] = None,
        expires_date: Optional[datetime] = None,
        environment: str = "Production",
    ) -> SubscriptionTransaction:
        """Records an authoritative transaction ledger entry."""
        payload_hash = hashlib.sha256(raw_payload.encode("utf-8")).hexdigest()
        tx = SubscriptionTransaction(
            user_id=user_id,
            subscription_id=subscription_id,
            provider=provider,
            transaction_id=transaction_id,
            original_transaction_id=original_transaction_id,
            product_id=product_id,
            purchase_date=purchase_date,
            expires_date=expires_date,
            environment=environment,
            raw_data_hash=payload_hash,
        )
        self.session.add(tx)
        await self.session.flush()
        await self.session.refresh(tx)
        return tx

    # -------------------------------------------------------------------------
    # Webhook Event Deduplication
    # -------------------------------------------------------------------------
    async def get_webhook_event(
        self, provider: str, provider_event_id: str
    ) -> Optional[SubscriptionWebhookEvent]:
        """Checks if webhook event has already been received."""
        stmt = select(SubscriptionWebhookEvent).where(
            and_(
                SubscriptionWebhookEvent.provider == provider,
                SubscriptionWebhookEvent.provider_event_id == provider_event_id,
            )
        )
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def record_webhook_event(
        self,
        provider: str,
        provider_event_id: str,
        event_type: str,
        raw_payload: str,
    ) -> SubscriptionWebhookEvent:
        """Stores webhook event with RECEIVED status."""
        payload_hash = hashlib.sha256(raw_payload.encode("utf-8")).hexdigest()
        event = SubscriptionWebhookEvent(
            provider=provider,
            provider_event_id=provider_event_id,
            event_type=event_type,
            status="RECEIVED",
            payload_hash=payload_hash,
        )
        self.session.add(event)
        await self.session.flush()
        await self.session.refresh(event)
        return event

    async def update_webhook_event_status(
        self,
        event_id: uuid.UUID,
        status: str,
        error_message: Optional[str] = None,
    ) -> None:
        """Updates webhook event processing status."""
        now = datetime.now(timezone.utc)
        stmt = (
            update(SubscriptionWebhookEvent)
            .where(SubscriptionWebhookEvent.id == event_id)
            .values(
                status=status,
                error_message=error_message,
                processed_at=now,
            )
        )
        await self.session.execute(stmt)
        await self.session.flush()
