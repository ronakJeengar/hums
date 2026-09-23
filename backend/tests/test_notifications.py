import uuid
from unittest.mock import MagicMock, patch
import pytest
from httpx import AsyncClient

from app.db.database import AsyncSessionLocal
from app.db.models.notification import Notification, NotificationPreference, UserDevice
from app.schemas.notification import NotificationPreferencesUpdate, NotificationType
from app.services.notification_service import NotificationService
from app.services.push import MockPushProvider, set_push_provider
from app.workers.notification_tasks import send_push_notification


@pytest.fixture
def mock_push():
    """Provides a fresh MockPushProvider for isolated push assertions."""
    provider = MockPushProvider()
    set_push_provider(provider)
    yield provider
    provider.clear()
    set_push_provider(None)


@pytest.fixture
async def user1_auth(async_client: AsyncClient):
    """Registers and authenticates User 1."""
    email = f"notif_user1_{uuid.uuid4().hex[:8]}@example.com"
    password = "SecurePassword123!"
    res = await async_client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": password, "name": "Notif User One"},
    )
    assert res.status_code == 201
    data = res.json()["data"]
    token = data["access_token"]
    return {
        "access_token": token,
        "headers": {"Authorization": f"Bearer {token}"},
        "user": data["user"],
        "user_id": uuid.UUID(data["user"]["id"]),
    }


@pytest.fixture
async def user2_auth(async_client: AsyncClient):
    """Registers and authenticates User 2."""
    email = f"notif_user2_{uuid.uuid4().hex[:8]}@example.com"
    password = "SecurePassword123!"
    res = await async_client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": password, "name": "Notif User Two"},
    )
    assert res.status_code == 201
    data = res.json()["data"]
    token = data["access_token"]
    return {
        "access_token": token,
        "headers": {"Authorization": f"Bearer {token}"},
        "user": data["user"],
        "user_id": uuid.UUID(data["user"]["id"]),
    }


# ===========================================================================
# 1. Device Registration Tests
# ===========================================================================

@pytest.mark.asyncio
async def test_register_device_token(async_client: AsyncClient, user1_auth):
    """Test registering a new device push token."""
    device_token = f"fcm_token_{uuid.uuid4().hex}"
    payload = {
        "token": device_token,
        "platform": "ANDROID",
        "device_name": "Pixel 8 Pro",
        "app_version": "1.0.0",
    }

    res = await async_client.post(
        "/api/v1/notifications/devices",
        json=payload,
        headers=user1_auth["headers"],
    )
    assert res.status_code == 201
    data = res.json()["data"]
    assert data["device_token"] == device_token
    assert data["platform"] == "ANDROID"
    assert data["device_name"] == "Pixel 8 Pro"
    assert data["is_active"] is True


@pytest.mark.asyncio
async def test_register_device_token_upsert(async_client: AsyncClient, user1_auth):
    """Test re-registering an existing token updates its metadata and active state."""
    device_token = f"fcm_token_{uuid.uuid4().hex}"

    # Initial registration
    res1 = await async_client.post(
        "/api/v1/notifications/devices",
        json={"token": device_token, "platform": "ANDROID", "device_name": "Old Phone"},
        headers=user1_auth["headers"],
    )
    assert res1.status_code == 201
    device_id = res1.json()["data"]["id"]

    # Re-register same token with new device name
    res2 = await async_client.post(
        "/api/v1/notifications/devices",
        json={"token": device_token, "platform": "IOS", "device_name": "New iPhone"},
        headers=user1_auth["headers"],
    )
    assert res2.status_code == 201
    data2 = res2.json()["data"]
    assert data2["id"] == device_id
    assert data2["platform"] == "IOS"
    assert data2["device_name"] == "New iPhone"
    assert data2["is_active"] is True


@pytest.mark.asyncio
async def test_register_multiple_devices_for_user(async_client: AsyncClient, user1_auth):
    """Test that a single user can have multiple active registered devices."""
    token1 = f"fcm_token_tablet_{uuid.uuid4().hex}"
    token2 = f"fcm_token_phone_{uuid.uuid4().hex}"

    res1 = await async_client.post(
        "/api/v1/notifications/devices",
        json={"token": token1, "platform": "ANDROID", "device_name": "Tablet"},
        headers=user1_auth["headers"],
    )
    assert res1.status_code == 201

    res2 = await async_client.post(
        "/api/v1/notifications/devices",
        json={"token": token2, "platform": "IOS", "device_name": "Phone"},
        headers=user1_auth["headers"],
    )
    assert res2.status_code == 201

    assert res1.json()["data"]["id"] != res2.json()["data"]["id"]


@pytest.mark.asyncio
async def test_deactivate_device_by_id(async_client: AsyncClient, user1_auth, user2_auth):
    """Test deactivating a device by ID and verifying user tenancy isolation."""
    device_token = f"fcm_token_{uuid.uuid4().hex}"
    reg_res = await async_client.post(
        "/api/v1/notifications/devices",
        json={"token": device_token, "platform": "ANDROID"},
        headers=user1_auth["headers"],
    )
    device_id = reg_res.json()["data"]["id"]

    # User 2 cannot deactivate User 1's device
    del_res_user2 = await async_client.delete(
        f"/api/v1/notifications/devices/{device_id}",
        headers=user2_auth["headers"],
    )
    assert del_res_user2.status_code == 404

    # User 1 deactivates own device
    del_res_user1 = await async_client.delete(
        f"/api/v1/notifications/devices/{device_id}",
        headers=user1_auth["headers"],
    )
    assert del_res_user1.status_code == 204


@pytest.mark.asyncio
async def test_deactivate_device_by_token(async_client: AsyncClient, user1_auth):
    """Test deactivating a device by token (e.g. on client logout)."""
    device_token = f"fcm_token_{uuid.uuid4().hex}"
    await async_client.post(
        "/api/v1/notifications/devices",
        json={"token": device_token, "platform": "ANDROID"},
        headers=user1_auth["headers"],
    )

    del_res = await async_client.delete(
        f"/api/v1/notifications/devices?token={device_token}",
        headers=user1_auth["headers"],
    )
    assert del_res.status_code == 204


# ===========================================================================
# 2. Notification Preferences Tests
# ===========================================================================

@pytest.mark.asyncio
async def test_get_and_update_notification_preferences(async_client: AsyncClient, user1_auth):
    """Test retrieving defaults and updating notification preferences."""
    # Get initial defaults
    get_res = await async_client.get(
        "/api/v1/notifications/preferences",
        headers=user1_auth["headers"],
    )
    assert get_res.status_code == 200
    pref_data = get_res.json()["data"]
    assert pref_data["push_enabled"] is True
    assert pref_data["new_releases_enabled"] is True
    assert pref_data["playlist_updates_enabled"] is True
    assert pref_data["recommendations_enabled"] is True
    assert pref_data["processing_updates_enabled"] is True

    # Update preferences
    update_res = await async_client.put(
        "/api/v1/notifications/preferences",
        json={
            "new_releases_enabled": False,
            "processing_updates_enabled": False,
        },
        headers=user1_auth["headers"],
    )
    assert update_res.status_code == 200
    updated_data = update_res.json()["data"]
    assert updated_data["push_enabled"] is True
    assert updated_data["new_releases_enabled"] is False
    assert updated_data["processing_updates_enabled"] is False
    assert updated_data["recommendations_enabled"] is True


# ===========================================================================
# 3. Notification History & Read State Tests
# ===========================================================================

@pytest.mark.asyncio
async def test_notification_history_and_read_states(async_client: AsyncClient, user1_auth, user2_auth):
    """Test inbox pagination, unread count, single read, and bulk read-all."""
    user1_id = user1_auth["user_id"]
    service = NotificationService()

    # Create 3 notifications for User 1
    n1 = await service.notify_user(
        user_id=user1_id,
        notification_type=NotificationType.NEW_RELEASE.value,
        title="New Track 1",
        body="Artist just dropped Track 1",
        data={"track_id": "1"},
        dispatch_push=False,
    )
    n2 = await service.notify_user(
        user_id=user1_id,
        notification_type=NotificationType.PLAYLIST_UPDATE.value,
        title="Playlist Updated",
        body="New songs were added to your playlist",
        data={"playlist_id": "2"},
        dispatch_push=False,
    )
    n3 = await service.notify_user(
        user_id=user1_id,
        notification_type=NotificationType.UPLOAD_COMPLETE.value,
        title="Upload Ready",
        body="Your upload is finished",
        dispatch_push=False,
    )

    # Verify unread count is 3
    count_res = await async_client.get(
        "/api/v1/notifications/unread-count",
        headers=user1_auth["headers"],
    )
    assert count_res.status_code == 200
    assert count_res.json()["data"]["unread_count"] == 3

    # List notifications
    list_res = await async_client.get(
        "/api/v1/notifications?limit=10",
        headers=user1_auth["headers"],
    )
    assert list_res.status_code == 200
    list_data = list_res.json()["data"]
    assert list_data["total"] >= 3
    assert len(list_data["items"]) >= 3

    # Mark single notification as read
    read_res = await async_client.patch(
        f"/api/v1/notifications/{n1.id}/read",
        headers=user1_auth["headers"],
    )
    assert read_res.status_code == 200
    assert read_res.json()["data"]["is_read"] is True

    # User 2 cannot mark User 1's notification as read
    unauth_read_res = await async_client.patch(
        f"/api/v1/notifications/{n2.id}/read",
        headers=user2_auth["headers"],
    )
    assert unauth_read_res.status_code == 404

    # Unread count should now be 2
    count_res2 = await async_client.get(
        "/api/v1/notifications/unread-count",
        headers=user1_auth["headers"],
    )
    assert count_res2.json()["data"]["unread_count"] == 2

    # Mark all as read
    read_all_res = await async_client.post(
        "/api/v1/notifications/read-all",
        headers=user1_auth["headers"],
    )
    assert read_all_res.status_code == 200
    assert read_all_res.json()["data"]["marked_count"] >= 2

    # Unread count should now be 0
    count_res3 = await async_client.get(
        "/api/v1/notifications/unread-count",
        headers=user1_auth["headers"],
    )
    assert count_res3.json()["data"]["unread_count"] == 0


# ===========================================================================
# 4. Push Provider & Celery Task Delivery Tests
# ===========================================================================

@pytest.mark.asyncio
async def test_notification_service_multicast_and_token_pruning(mock_push: MockPushProvider, user1_auth):
    """Test delivering push to multiple devices and auto-deactivating invalid tokens."""
    user1_id = user1_auth["user_id"]
    service = NotificationService(push_provider=mock_push)

    valid_token = f"valid_token_{uuid.uuid4().hex}"
    invalid_token = f"unregistered-device-token_{uuid.uuid4().hex}"

    # Register both valid and invalid device tokens
    await service.register_device(user_id=user1_id, token=valid_token, platform="ANDROID")
    await service.register_device(user_id=user1_id, token=invalid_token, platform="IOS")

    # Deliver push
    result = await service.deliver_to_user_devices(
        user_id=user1_id,
        title="Test Push",
        body="Testing device dispatch and pruning",
        data={"key": "value"},
    )

    assert result.success_count == 1
    assert result.failure_count == 1
    assert invalid_token in result.invalid_tokens

    # Verify that invalid token was automatically deactivated in DB
    async with AsyncSessionLocal() as session:
        from app.repositories.notification_repository import UserDeviceRepository

        repo = UserDeviceRepository(session)
        active_devices = await repo.get_active_devices_by_user_id(user1_id)
        active_tokens = [d.device_token for d in active_devices]
        assert valid_token in active_tokens
        assert invalid_token not in active_tokens


@pytest.mark.asyncio
async def test_notification_service_idempotency_key(user1_auth):
    """Test that notify_user deduplicates identical events using idempotency_key."""
    user1_id = user1_auth["user_id"]
    service = NotificationService()
    idempotency_key = f"unique_event_{uuid.uuid4().hex}"

    n1 = await service.notify_user(
        user_id=user1_id,
        notification_type=NotificationType.UPLOAD_COMPLETE.value,
        title="Upload Ready",
        body="Version 1",
        idempotency_key=idempotency_key,
        dispatch_push=False,
    )

    # Second call with identical idempotency key
    n2 = await service.notify_user(
        user_id=user1_id,
        notification_type=NotificationType.UPLOAD_COMPLETE.value,
        title="Upload Ready",
        body="Version 2",
        idempotency_key=idempotency_key,
        dispatch_push=False,
    )

    assert n1.id == n2.id
    assert n1.title == n2.title


@pytest.mark.asyncio
async def test_push_preference_filtering(mock_push: MockPushProvider, user1_auth):
    """Test that notify_user does not dispatch push when category is disabled."""
    user1_id = user1_auth["user_id"]
    service = NotificationService(push_provider=mock_push)

    # Register valid token
    valid_token = f"valid_token_{uuid.uuid4().hex}"
    await service.register_device(user_id=user1_id, token=valid_token, platform="ANDROID")

    # Disable new releases
    await service.update_preferences(
        user_id=user1_id,
        update_data=NotificationPreferencesUpdate(new_releases_enabled=False),
    )

    with patch.object(service, "_queue_push_delivery") as mock_queue:
        await service.notify_user(
            user_id=user1_id,
            notification_type=NotificationType.NEW_RELEASE.value,
            title="Ignored Push",
            body="Should not queue push",
            dispatch_push=True,
        )
        # Push should not be queued because preference is disabled
        mock_queue.assert_not_called()


def test_celery_send_push_notification_task(mock_push: MockPushProvider):
    """Test Celery worker task execution for push delivery."""
    fake_user_id = uuid.uuid4()
    # Execute task synchronously
    success = send_push_notification.apply(
        args=[str(fake_user_id), "Celery Test", "Push from worker"],
        kwargs={"data": {"screen": "home"}},
    ).get()

    assert success is True
