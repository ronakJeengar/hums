import uuid
import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.db.models.user import User
from app.db.models.creator import Creator


@pytest.fixture
async def listener_user(async_client: AsyncClient) -> dict:
    email = f"listener_{uuid.uuid4().hex[:8]}@example.com"
    res = await async_client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": "Password123!", "name": "Listener User"},
    )
    assert res.status_code == 201
    data = res.json()["data"]
    return {
        "headers": {"Authorization": f"Bearer {data['access_token']}"},
        "user_id": uuid.UUID(data["user"]["id"]),
        "email": email,
    }


@pytest.fixture
async def admin_user(async_client: AsyncClient, db_session: AsyncSession) -> dict:
    email = f"admin_{uuid.uuid4().hex[:8]}@example.com"
    res = await async_client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": "Password123!", "name": "System Admin"},
    )
    assert res.status_code == 201
    data = res.json()["data"]
    user_id = uuid.UUID(data["user"]["id"])

    # Promote to admin directly in db
    result = await db_session.execute(select(User).where(User.id == user_id))
    user = result.scalar_one()
    user.role = "admin"
    await db_session.commit()

    # Re-login to get fresh token with admin role
    login_res = await async_client.post(
        "/api/v1/auth/login",
        json={"email": email, "password": "Password123!"},
    )
    assert login_res.status_code == 200
    token = login_res.json()["data"]["access_token"]

    return {
        "headers": {"Authorization": f"Bearer {token}"},
        "user_id": user_id,
        "email": email,
    }


@pytest.fixture
async def creator_user(async_client: AsyncClient, db_session: AsyncSession) -> dict:
    email = f"creator_{uuid.uuid4().hex[:8]}@example.com"
    res = await async_client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": "Password123!", "name": "Verified Creator"},
    )
    assert res.status_code == 201
    data = res.json()["data"]
    user_id = uuid.UUID(data["user"]["id"])

    # Promote to creator in db
    result = await db_session.execute(select(User).where(User.id == user_id))
    user = result.scalar_one()
    user.role = "creator"

    creator_entity = Creator(
        id=uuid.uuid4(),
        user_id=user_id,
        name="Verified Creator",
        bio="Test creator bio",
        followers_count=15,
        is_verified=True,
    )
    db_session.add(creator_entity)
    await db_session.commit()

    # Re-login
    login_res = await async_client.post(
        "/api/v1/auth/login",
        json={"email": email, "password": "Password123!"},
    )
    assert login_res.status_code == 200
    token = login_res.json()["data"]["access_token"]

    return {
        "headers": {"Authorization": f"Bearer {token}"},
        "user_id": user_id,
        "email": email,
        "creator_id": creator_entity.id,
    }


# ============================================================================
# 1. Admin Access Control & Dashboard Tests
# ============================================================================

@pytest.mark.asyncio
async def test_admin_access_control(async_client: AsyncClient, listener_user: dict, admin_user: dict):
    # Unauthenticated
    unauth_res = await async_client.get("/api/v1/admin/dashboard")
    assert unauth_res.status_code == 401

    # Listener user (forbidden)
    forbidden_res = await async_client.get("/api/v1/admin/dashboard", headers=listener_user["headers"])
    assert forbidden_res.status_code == 403

    # Admin user (permitted)
    admin_res = await async_client.get("/api/v1/admin/dashboard", headers=admin_user["headers"])
    assert admin_res.status_code == 200
    data = admin_res.json()["data"]
    assert "total_users" in data
    assert "published_tracks" in data
    assert "pending_applications" in data
    assert "subscriptions_summary" in data


# ============================================================================
# 2. Admin User Management Tests
# ============================================================================

@pytest.mark.asyncio
async def test_admin_user_management(
    async_client: AsyncClient, admin_user: dict, listener_user: dict
):
    # List users
    res = await async_client.get("/api/v1/admin/users", headers=admin_user["headers"])
    assert res.status_code == 200
    users_data = res.json()["data"]
    assert "items" in users_data
    assert users_data["total"] >= 1

    # Get specific user detail
    target_id = str(listener_user["user_id"])
    detail_res = await async_client.get(
        f"/api/v1/admin/users/{target_id}", headers=admin_user["headers"]
    )
    assert detail_res.status_code == 200
    assert detail_res.json()["data"]["email"] == listener_user["email"]

    # Update role
    role_res = await async_client.patch(
        f"/api/v1/admin/users/{target_id}/role",
        headers=admin_user["headers"],
        json={"role": "moderator", "reason": "Promoted to support team"},
    )
    assert role_res.status_code == 200
    assert role_res.json()["data"]["role"] == "moderator"

    # Suspend user
    status_res = await async_client.patch(
        f"/api/v1/admin/users/{target_id}/status",
        headers=admin_user["headers"],
        json={"is_active": False, "reason": "Terms violation"},
    )
    assert status_res.status_code == 200
    assert status_res.json()["data"]["is_active"] is False

    # Check Audit Log was recorded
    audit_res = await async_client.get(
        "/api/v1/admin/audit-logs",
        headers=admin_user["headers"],
        params={"target_type": "user"},
    )
    assert audit_res.status_code == 200
    items = audit_res.json()["data"]["items"]
    assert any(item["action"] == "USER_ROLE_CHANGE" for item in items)


# ============================================================================
# 3. Creator Application Flow Tests
# ============================================================================

@pytest.mark.asyncio
async def test_creator_application_lifecycle(
    async_client: AsyncClient, listener_user: dict, admin_user: dict
):
    # Listener submits application
    apply_res = await async_client.post(
        "/api/v1/creator-applications",
        headers=listener_user["headers"],
        json={
            "artist_name": "Indie Band Alpha",
            "bio": "Alternative indie rock project.",
            "genres": "Indie, Rock",
            "portfolio_url": "https://soundcloud.com/indie-alpha",
        },
    )
    assert apply_res.status_code == 201
    app_id = apply_res.json()["data"]["id"]
    assert apply_res.json()["data"]["status"] == "PENDING"

    # Listener checks own application
    my_app_res = await async_client.get(
        "/api/v1/creator-applications/me", headers=listener_user["headers"]
    )
    assert my_app_res.status_code == 200
    assert my_app_res.json()["data"]["id"] == app_id

    # Admin reviews and approves application
    review_res = await async_client.patch(
        f"/api/v1/admin/creator-applications/{app_id}",
        headers=admin_user["headers"],
        json={"status": "APPROVED", "review_notes": "Great sound portfolio. Approved!"},
    )
    assert review_res.status_code == 200
    assert review_res.json()["data"]["status"] == "APPROVED"

    # Check user detail now reflects creator role
    user_detail_res = await async_client.get(
        f"/api/v1/admin/users/{listener_user['user_id']}",
        headers=admin_user["headers"],
    )
    assert user_detail_res.status_code == 200
    assert user_detail_res.json()["data"]["role"] == "creator"
    assert user_detail_res.json()["data"]["has_creator_profile"] is True


# ============================================================================
# 4. Content Violation Reporting & Resolution Tests
# ============================================================================

@pytest.mark.asyncio
async def test_content_reporting_and_resolution(
    async_client: AsyncClient, listener_user: dict, admin_user: dict
):
    # User submits violation report
    report_res = await async_client.post(
        "/api/v1/reports",
        headers=listener_user["headers"],
        json={
            "entity_type": "track",
            "entity_id": str(uuid.uuid4()),
            "reason": "COPYRIGHT",
            "description": "Unauthorized cover song posted without licensing.",
        },
    )
    assert report_res.status_code == 201
    report_id = report_res.json()["data"]["id"]
    assert report_res.json()["data"]["status"] == "PENDING"

    # Admin sees report in queue
    list_reports_res = await async_client.get(
        "/api/v1/admin/reports",
        headers=admin_user["headers"],
        params={"reason": "COPYRIGHT"},
    )
    assert list_reports_res.status_code == 200
    assert list_reports_res.json()["data"]["total"] >= 1

    # Admin resolves report
    resolve_res = await async_client.patch(
        f"/api/v1/admin/reports/{report_id}",
        headers=admin_user["headers"],
        json={
            "status": "RESOLVED",
            "action_taken": "TRACK_MODERATED",
            "resolution_notes": "Takedown notice processed.",
        },
    )
    assert resolve_res.status_code == 200
    assert resolve_res.json()["data"]["status"] == "RESOLVED"
    assert resolve_res.json()["data"]["action_taken"] == "TRACK_MODERATED"


# ============================================================================
# 5. Creator Studio Endpoints & Features
# ============================================================================

@pytest.mark.asyncio
async def test_creator_studio_capabilities(
    async_client: AsyncClient, creator_user: dict, listener_user: dict
):
    # Non-creator gets 403
    forbidden_res = await async_client.get(
        "/api/v1/creator-studio/dashboard", headers=listener_user["headers"]
    )
    assert forbidden_res.status_code == 403

    # Creator gets dashboard
    dash_res = await async_client.get(
        "/api/v1/creator-studio/dashboard", headers=creator_user["headers"]
    )
    assert dash_res.status_code == 200
    assert "published_tracks" in dash_res.json()["data"]

    # Creator lists tracks
    tracks_res = await async_client.get(
        "/api/v1/creator-studio/tracks", headers=creator_user["headers"]
    )
    assert tracks_res.status_code == 200
    assert "items" in tracks_res.json()["data"]

    # Creator analytics
    analytics_res = await async_client.get(
        "/api/v1/creator-studio/analytics",
        headers=creator_user["headers"],
        params={"period": "30d"},
    )
    assert analytics_res.status_code == 200
    assert "plays_timeline" in analytics_res.json()["data"]

    # Creator profile get and update
    profile_res = await async_client.get(
        "/api/v1/creator-studio/profile", headers=creator_user["headers"]
    )
    assert profile_res.status_code == 200

    update_profile_res = await async_client.patch(
        "/api/v1/creator-studio/profile",
        headers=creator_user["headers"],
        json={"bio": "Updated artist bio for testing."},
    )
    assert update_profile_res.status_code == 200
    assert update_profile_res.json()["data"]["bio"] == "Updated artist bio for testing."


# ============================================================================
# 6. Platform Operations & Health Check
# ============================================================================

@pytest.mark.asyncio
async def test_system_operations_health(async_client: AsyncClient, admin_user: dict):
    health_res = await async_client.get(
        "/api/v1/admin/operations/health", headers=admin_user["headers"]
    )
    assert health_res.status_code == 200
    data = health_res.json()["data"]
    assert "database" in data
    assert "redis" in data
    assert "celery_broker" in data
    assert "storage" in data
