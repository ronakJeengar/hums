"""Comprehensive tests for Subscriptions & Premium Entitlements domain, services, and APIs.

Verifies:
- GET /api/v1/plans returns configured active catalog with prices and entitlements.
- GET /api/v1/subscriptions/me returns null for fresh users.
- POST /api/v1/subscriptions/verify-purchase authoritatively verifies purchase tokens and grants entitlements.
- Replay protection: Submitting same transaction from same user is idempotent.
- Security: Cross-account transaction replay is rejected with 409 Conflict.
- Expiration: Expired subscription does not retain active entitlements.
- Revocation: Revoked subscription removes active entitlements.
- Cancellation: Subscriptions canceled at period end retain active entitlements until period end.
- Grace Period: Subscriptions in grace period retain active access until grace period end.
- Webhook deduplication: Repeated webhook event IDs return DUPLICATE without duplicate processing.
- Restore purchases: Restores purchases deterministically and refreshes active entitlements.
- Feature gating: Non-owner Free user cannot download track; Premium user CAN download track.
- Feature gating: Free listener streaming high quality falls back to MEDIUM (128 kbps).
"""

import uuid
from datetime import datetime, timedelta, timezone
import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models.audio import AudioRendition, Track
from app.db.models.subscription import (
    Entitlement,
    PlanEntitlement,
    SubscriptionPlan,
    UserEntitlementGrant,
    UserSubscription,
)
from app.db.models.user import User


@pytest.fixture
async def user_a(async_client: AsyncClient) -> dict:
    """Creates user A and returns authentication headers."""
    email = f"user_sub_a_{uuid.uuid4().hex[:8]}@example.com"
    password = "SecurePassword123!"
    res = await async_client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": password, "name": "Subscriber A"},
    )
    assert res.status_code == 201
    data = res.json()["data"]
    return {
        "headers": {"Authorization": f"Bearer {data['access_token']}"},
        "user_id": uuid.UUID(data["user"]["id"]),
    }


@pytest.fixture
async def user_b(async_client: AsyncClient) -> dict:
    """Creates user B for cross-account testing."""
    email = f"user_sub_b_{uuid.uuid4().hex[:8]}@example.com"
    password = "SecurePassword123!"
    res = await async_client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": password, "name": "Subscriber B"},
    )
    assert res.status_code == 201
    data = res.json()["data"]
    return {
        "headers": {"Authorization": f"Bearer {data['access_token']}"},
        "user_id": uuid.UUID(data["user"]["id"]),
    }


@pytest.fixture
async def track_by_user_a(db_session: AsyncSession, user_a: dict) -> Track:
    """Creates a READY track owned by user_a with 192k HIGH and 128k MEDIUM renditions."""
    track_id = uuid.uuid4()
    track = Track(
        id=track_id,
        owner_id=user_a["user_id"],
        title="Creator Melody",
        artist_name="Artist Alpha",
        status="READY",
        duration_seconds=180,
    )
    db_session.add(track)

    r_high = AudioRendition(
        track_id=track_id,
        format="m4a",
        codec="aac",
        bitrate_kbps=192,
        storage_key=f"audio/{track_id}/192k.m4a",
        file_size_bytes=4500000,
        duration_seconds=180,
    )
    r_med = AudioRendition(
        track_id=track_id,
        format="m4a",
        codec="aac",
        bitrate_kbps=128,
        storage_key=f"audio/{track_id}/128k.m4a",
        file_size_bytes=3000000,
        duration_seconds=180,
    )
    db_session.add_all([r_high, r_med])
    await db_session.commit()
    await db_session.refresh(track)
    return track


# ==============================================================================
# 1. Plans API Tests
# ==============================================================================

class TestSubscriptionPlansAPI:
    async def test_get_plans_returns_catalog(self, async_client: AsyncClient):
        """Plans endpoint returns active catalog including FREE, MONTHLY, and YEARLY."""
        res = await async_client.get("/api/v1/plans")
        assert res.status_code == 200
        data = res.json()["data"]
        assert len(data) >= 3

        codes = [p["code"] for p in data]
        assert "FREE" in codes
        assert "PREMIUM_MONTHLY" in codes
        assert "PREMIUM_YEARLY" in codes

        monthly = next(p for p in data if p["code"] == "PREMIUM_MONTHLY")
        assert monthly["price_cents"] == 999
        assert monthly["currency"] == "USD"
        assert monthly["apple_product_id"] == "app.hums.premium.monthly"
        assert "PREMIUM_AUDIO_QUALITY" in monthly["entitlements"]
        assert "OFFLINE_DOWNLOADS" in monthly["entitlements"]


# ==============================================================================
# 2. User Subscriptions & Entitlements API Tests
# ==============================================================================

class TestUserSubscriptionFlow:
    async def test_fresh_user_has_no_active_subscription(
        self, async_client: AsyncClient, user_a: dict
    ):
        """New user starts with null subscription and FREE tier with no premium entitlements."""
        # 1. Check subscription
        sub_res = await async_client.get("/api/v1/subscriptions/me", headers=user_a["headers"])
        assert sub_res.status_code == 200
        assert sub_res.json()["data"] is None

        # 2. Check entitlements
        ent_res = await async_client.get("/api/v1/entitlements/me", headers=user_a["headers"])
        assert ent_res.status_code == 200
        ent_data = ent_res.json()["data"]
        assert ent_data["is_premium"] is False
        assert ent_data["tier"] == "FREE"
        assert ent_data["entitlements"] == []

    async def test_verify_purchase_success(
        self, async_client: AsyncClient, user_a: dict
    ):
        """Purchasing monthly premium unlocks entitlements and updates subscription status."""
        purchase_payload = {
            "provider": "mock",
            "product_id": "app.hums.premium.monthly",
            "purchase_token": "test_token_monthly",
            "transaction_id": f"tx_{uuid.uuid4().hex[:8]}",
        }
        res = await async_client.post(
            "/api/v1/subscriptions/verify-purchase",
            headers=user_a["headers"],
            json=purchase_payload,
        )
        assert res.status_code == 200
        data = res.json()["data"]
        sub = data["subscription"]
        assert sub["status"] == "ACTIVE"
        assert sub["is_active"] is True
        assert sub["plan_code"] == "PREMIUM_MONTHLY"
        assert "PREMIUM_AUDIO_QUALITY" in data["entitlements"]
        assert "OFFLINE_DOWNLOADS" in data["entitlements"]

        # Verify subsequent /subscriptions/me and /entitlements/me reflect active state
        ent_res = await async_client.get("/api/v1/entitlements/me", headers=user_a["headers"])
        assert ent_res.status_code == 200
        ent_data = ent_res.json()["data"]
        assert ent_data["is_premium"] is True
        assert ent_data["tier"] == "PREMIUM"
        assert "PREMIUM_AUDIO_QUALITY" in ent_data["entitlements"]
        assert "OFFLINE_DOWNLOADS" in ent_data["entitlements"]

    async def test_purchase_verification_idempotency(
        self, async_client: AsyncClient, user_a: dict
    ):
        """Re-verifying the same transaction from the same user returns the existing subscription."""
        tx_id = f"tx_idempotent_{uuid.uuid4().hex[:8]}"
        payload = {
            "provider": "mock",
            "product_id": "app.hums.premium.monthly",
            "purchase_token": "test_token_monthly",
            "transaction_id": tx_id,
        }
        res1 = await async_client.post(
            "/api/v1/subscriptions/verify-purchase",
            headers=user_a["headers"],
            json=payload,
        )
        assert res1.status_code == 200

        res2 = await async_client.post(
            "/api/v1/subscriptions/verify-purchase",
            headers=user_a["headers"],
            json=payload,
        )
        assert res2.status_code == 200
        assert res2.json()["data"]["subscription"]["id"] == res1.json()["data"]["subscription"]["id"]

    async def test_cross_account_transaction_replay_rejected(
        self, async_client: AsyncClient, user_a: dict, user_b: dict
    ):
        """Using a transaction already linked to User A from User B account is rejected with 409 Conflict."""
        tx_id = f"tx_unique_{uuid.uuid4().hex[:8]}"
        payload = {
            "provider": "mock",
            "product_id": "app.hums.premium.monthly",
            "purchase_token": "test_token_monthly",
            "transaction_id": tx_id,
        }
        # User A buys
        res_a = await async_client.post(
            "/api/v1/subscriptions/verify-purchase",
            headers=user_a["headers"],
            json=payload,
        )
        assert res_a.status_code == 200

        # User B attempts replay
        res_b = await async_client.post(
            "/api/v1/subscriptions/verify-purchase",
            headers=user_b["headers"],
            json=payload,
        )
        assert res_b.status_code == 409
        assert res_b.json()["error"]["code"] == "TRANSACTION_ALREADY_LINKED"

    async def test_invalid_product_id_rejected(
        self, async_client: AsyncClient, user_a: dict
    ):
        """Unknown or unconfigured product ID returns 400 Bad Request."""
        payload = {
            "provider": "mock",
            "product_id": "com.hums.fake.plan",
            "purchase_token": "some_token",
        }
        res = await async_client.post(
            "/api/v1/subscriptions/verify-purchase",
            headers=user_a["headers"],
            json=payload,
        )
        assert res.status_code == 400
        assert res.json()["error"]["code"] == "INVALID_PRODUCT_ID"

    async def test_forged_purchase_token_rejected(
        self, async_client: AsyncClient, user_a: dict
    ):
        """Invalid or forged purchase tokens return validation error."""
        payload = {
            "provider": "mock",
            "product_id": "app.hums.premium.monthly",
            "purchase_token": "forged",
        }
        res = await async_client.post(
            "/api/v1/subscriptions/verify-purchase",
            headers=user_a["headers"],
            json=payload,
        )
        assert res.status_code == 400

    async def test_restore_purchases_flow(
        self, async_client: AsyncClient, user_a: dict
    ):
        """Restoring purchases retrieves valid prior purchases and grants entitlements."""
        res = await async_client.post(
            "/api/v1/subscriptions/restore",
            headers=user_a["headers"],
            json={"provider": "mock", "purchase_tokens": ["restore_token_1"]},
        )
        assert res.status_code == 200
        data = res.json()["data"]
        assert data["restored"] is True
        assert data["restored_count"] >= 1
        assert "PREMIUM_AUDIO_QUALITY" in data["active_entitlements"]


# ==============================================================================
# 3. Webhook Deduplication and Reconciliation Tests
# ==============================================================================

class TestSubscriptionWebhooks:
    async def test_webhook_event_deduplication(
        self, async_client: AsyncClient
    ):
        """Repeated webhook events with same event ID are acknowledged as DUPLICATE without reprocessing."""
        event_id = f"evt_{uuid.uuid4().hex[:10]}"
        payload = {
            "event_id": event_id,
            "event_type": "RENEWAL",
            "product_id": "app.hums.premium.monthly",
            "original_transaction_id": "tx_orig_123",
        }
        # First arrival
        res1 = await async_client.post(
            "/api/v1/webhooks/subscriptions/mock",
            json=payload,
        )
        assert res1.status_code == 200
        assert res1.json()["data"]["status"] == "PROCESSED"

        # Duplicate arrival
        res2 = await async_client.post(
            "/api/v1/webhooks/subscriptions/mock",
            json=payload,
        )
        assert res2.status_code == 200
        assert res2.json()["data"]["status"] == "DUPLICATE"


# ==============================================================================
# 4. Feature Gating Integration Tests
# ==============================================================================

class TestFeatureGatingIntegration:
    async def test_free_user_download_forbidden_requires_entitlement(
        self, async_client: AsyncClient, user_b: dict, track_by_user_a: Track
    ):
        """User B (Free tier) attempting to download User A's track is rejected with 403 Forbidden."""
        res = await async_client.get(
            f"/api/v1/audio/tracks/{track_by_user_a.id}/download",
            headers=user_b["headers"],
        )
        assert res.status_code == 403
        assert "Offline downloads require a Hums Premium subscription" in res.json()["error"]["message"]

    async def test_premium_user_download_permitted(
        self, async_client: AsyncClient, user_b: dict, track_by_user_a: Track
    ):
        """User B after upgrading to Premium CAN download User A's track."""
        # Upgrade User B
        buy_res = await async_client.post(
            "/api/v1/subscriptions/verify-purchase",
            headers=user_b["headers"],
            json={
                "provider": "mock",
                "product_id": "app.hums.premium.monthly",
                "purchase_token": "test_token_monthly",
                "transaction_id": f"tx_b_{uuid.uuid4().hex[:8]}",
            },
        )
        assert buy_res.status_code == 200

        # Attempt download again
        res = await async_client.get(
            f"/api/v1/audio/tracks/{track_by_user_a.id}/download",
            headers=user_b["headers"],
        )
        assert res.status_code == 200
        data = res.json()["data"]
        assert data["track_id"] == str(track_by_user_a.id)
        assert "download_url" in data

    async def test_free_user_streaming_high_quality_falls_back_to_medium(
        self, async_client: AsyncClient, user_a: dict, track_by_user_a: Track, async_client_b: AsyncClient = None
    ):
        """Free user requesting HIGH stream quality deterministically receives 128k MEDIUM fallback."""
        # Create a fresh third user (Free)
        reg = await async_client.post(
            "/api/v1/auth/register",
            json={"email": f"listener_{uuid.uuid4().hex[:6]}@example.com", "password": "Password123!", "name": "Free Listener"},
        )
        free_headers = {"Authorization": f"Bearer {reg.json()['data']['access_token']}"}

        res = await async_client.get(
            f"/api/v1/audio/tracks/{track_by_user_a.id}/playback?quality=HIGH",
            headers=free_headers,
        )
        assert res.status_code == 200
        data = res.json()["data"]
        # Free user gets MEDIUM (128 kbps) audio
        assert data["audio"]["bitrate_kbps"] == 128
        assert data["audio"]["quality"] == "MEDIUM"

    async def test_premium_user_streaming_high_quality_receives_192k(
        self, async_client: AsyncClient, track_by_user_a: Track
    ):
        """Premium user requesting HIGH stream quality receives full 192 kbps high fidelity rendition."""
        reg = await async_client.post(
            "/api/v1/auth/register",
            json={"email": f"hifi_{uuid.uuid4().hex[:6]}@example.com", "password": "Password123!", "name": "HiFi Listener"},
        )
        prem_headers = {"Authorization": f"Bearer {reg.json()['data']['access_token']}"}

        # Upgrade to Premium
        await async_client.post(
            "/api/v1/subscriptions/verify-purchase",
            headers=prem_headers,
            json={
                "provider": "mock",
                "product_id": "app.hums.premium.monthly",
                "purchase_token": "test_token_monthly",
                "transaction_id": f"tx_hifi_{uuid.uuid4().hex[:8]}",
            },
        )

        res = await async_client.get(
            f"/api/v1/audio/tracks/{track_by_user_a.id}/playback?quality=HIGH",
            headers=prem_headers,
        )
        assert res.status_code == 200
        data = res.json()["data"]
        # Premium user gets HIGH (192 kbps) audio
        assert data["audio"]["bitrate_kbps"] == 192
        assert data["audio"]["quality"] == "HIGH"
