import uuid
from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel, ConfigDict, Field


class PlanEntitlementSummary(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    code: str
    name: str
    description: Optional[str] = None


class SubscriptionPlanResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    code: str
    name: str
    description: Optional[str] = None
    billing_interval: str
    price_cents: int
    currency: str
    apple_product_id: Optional[str] = None
    google_product_id: Optional[str] = None
    is_active: bool
    display_order: int
    entitlements: List[str] = Field(default_factory=list)


class UserSubscriptionResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    user_id: uuid.UUID
    plan_code: str
    plan_name: str
    provider: str
    provider_subscription_id: Optional[str] = None
    provider_product_id: Optional[str] = None
    status: str
    is_active: bool
    current_period_start: datetime
    current_period_end: datetime
    cancel_at_period_end: bool
    grace_period_end: Optional[datetime] = None
    active_entitlements: List[str] = Field(default_factory=list)


class PurchaseVerificationRequest(BaseModel):
    provider: str = Field(..., description="Payment provider: 'apple', 'google', or 'mock'")
    product_id: str = Field(..., min_length=1, max_length=100, description="Platform product ID")
    purchase_token: str = Field(..., min_length=1, description="StoreKit 2 JWS token or Google Play purchase token")
    transaction_id: Optional[str] = Field(None, description="Client transaction identifier if available")
    original_transaction_id: Optional[str] = Field(None, description="Original transaction identifier if available")


class PurchaseVerificationResponse(BaseModel):
    subscription: UserSubscriptionResponse
    entitlements: List[str] = Field(default_factory=list)
    message: str = "Purchase successfully verified and entitlements granted."


class PurchaseRestoreRequest(BaseModel):
    provider: str = Field(..., description="Payment provider: 'apple', 'google', or 'mock'")
    receipt_data: Optional[str] = Field(None, description="App Store receipt / JWS transaction payload")
    purchase_tokens: Optional[List[str]] = Field(None, description="Array of Google Play purchase tokens")


class PurchaseRestoreResponse(BaseModel):
    restored: bool
    active_subscription: Optional[UserSubscriptionResponse] = None
    active_entitlements: List[str] = Field(default_factory=list)
    restored_count: int = 0
    message: str


class UserEntitlementsResponse(BaseModel):
    entitlements: List[str] = Field(default_factory=list)
    is_premium: bool = False
    tier: str = "FREE"
    expires_at: Optional[datetime] = None


class WebhookEventResponse(BaseModel):
    received: bool = True
    event_id: str
    status: str
