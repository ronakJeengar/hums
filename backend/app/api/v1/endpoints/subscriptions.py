from typing import List, Optional
from fastapi import APIRouter, Depends, Header, Request, status

from app.core.dependencies import (
    get_current_user,
    get_entitlement_service,
    get_subscription_service,
)
from app.core.rate_limit import RateLimiter
from app.db.models.user import User
from app.schemas.common import ApiResponse
from app.schemas.subscription import (
    PurchaseRestoreRequest,
    PurchaseRestoreResponse,
    PurchaseVerificationRequest,
    PurchaseVerificationResponse,
    SubscriptionPlanResponse,
    UserEntitlementsResponse,
    UserSubscriptionResponse,
    WebhookEventResponse,
)
from app.services.entitlement_service import EntitlementService
from app.services.subscription_service import SubscriptionService

router = APIRouter()


@router.get(
    "/plans",
    response_model=ApiResponse[List[SubscriptionPlanResponse]],
    status_code=status.HTTP_200_OK,
    summary="List available subscription plans",
    description="Returns the active catalog of subscription plans, pricing, and platform product IDs.",
)
async def list_subscription_plans(
    subscription_service: SubscriptionService = Depends(get_subscription_service),
) -> ApiResponse[List[SubscriptionPlanResponse]]:
    plans = await subscription_service.list_plans()
    return ApiResponse(data=plans)


@router.get(
    "/subscriptions/me",
    response_model=ApiResponse[Optional[UserSubscriptionResponse]],
    status_code=status.HTTP_200_OK,
    summary="Get current user subscription",
    description="Retrieves the authenticated user's current or latest subscription status, renewal date, and billing metadata.",
)
async def get_my_subscription(
    current_user: User = Depends(get_current_user),
    subscription_service: SubscriptionService = Depends(get_subscription_service),
) -> ApiResponse[Optional[UserSubscriptionResponse]]:
    sub = await subscription_service.get_user_subscription(current_user.id)
    return ApiResponse(data=sub)


@router.post(
    "/subscriptions/verify-purchase",
    response_model=ApiResponse[PurchaseVerificationResponse],
    status_code=status.HTTP_200_OK,
    summary="Verify store purchase and grant entitlements",
    description="Validates in-app purchase token with authoritative platform provider, prevents replay attacks, and grants entitlements.",
    dependencies=[Depends(RateLimiter(requests=10, window_seconds=60, action="purchase_verify"))],
)
async def verify_purchase(
    request_data: PurchaseVerificationRequest,
    current_user: User = Depends(get_current_user),
    subscription_service: SubscriptionService = Depends(get_subscription_service),
) -> ApiResponse[PurchaseVerificationResponse]:
    result = await subscription_service.verify_purchase(
        user_id=current_user.id,
        request=request_data,
    )
    return ApiResponse(data=result)


@router.post(
    "/subscriptions/restore",
    response_model=ApiResponse[PurchaseRestoreResponse],
    status_code=status.HTTP_200_OK,
    summary="Restore previous platform purchases",
    description="Restores existing Apple App Store or Google Play subscriptions for the authenticated user.",
    dependencies=[Depends(RateLimiter(requests=10, window_seconds=60, action="purchase_restore"))],
)
async def restore_purchases(
    request_data: PurchaseRestoreRequest,
    current_user: User = Depends(get_current_user),
    subscription_service: SubscriptionService = Depends(get_subscription_service),
) -> ApiResponse[PurchaseRestoreResponse]:
    result = await subscription_service.restore_purchases(
        user_id=current_user.id,
        request=request_data,
    )
    return ApiResponse(data=result)


@router.get(
    "/entitlements/me",
    response_model=ApiResponse[UserEntitlementsResponse],
    status_code=status.HTTP_200_OK,
    summary="Get current user active entitlements",
    description="Returns the authenticated user's active entitlements, tier, and subscription expiry.",
)
async def get_my_entitlements(
    current_user: User = Depends(get_current_user),
    entitlement_service: EntitlementService = Depends(get_entitlement_service),
) -> ApiResponse[UserEntitlementsResponse]:
    summary = await entitlement_service.get_user_entitlements_summary(current_user.id)
    return ApiResponse(data=summary)


@router.post(
    "/webhooks/subscriptions/{provider}",
    response_model=ApiResponse[WebhookEventResponse],
    status_code=status.HTTP_200_OK,
    summary="Store subscription lifecycle webhook",
    description="Receives and processes asynchronous subscription lifecycle notifications from Apple, Google, or testing providers.",
)
async def subscription_webhook(
    provider: str,
    request: Request,
    subscription_service: SubscriptionService = Depends(get_subscription_service),
) -> ApiResponse[WebhookEventResponse]:
    headers = dict(request.headers)
    body = await request.body()
    result = await subscription_service.handle_webhook(
        provider_name=provider,
        headers=headers,
        body=body,
    )
    return ApiResponse(data=result)
