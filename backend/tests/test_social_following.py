import asyncio
import uuid
import pytest
from httpx import AsyncClient

from app.db.database import AsyncSessionLocal
from app.db.models.creator import Creator, CreatorFollower
from app.db.models.audio import Track
from app.repositories.creator_repository import CreatorRepository
from app.repositories.audio_repository import TrackRepository


@pytest.fixture
async def social_user1(async_client: AsyncClient):
    """User 1 fixture."""
    email = f"social_u1_{uuid.uuid4().hex[:8]}@example.com"
    password = "SecurePassword123!"
    res = await async_client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": password, "name": "Aarav Sharma"},
    )
    assert res.status_code == 201
    data = res.json()["data"]
    token = data["access_token"]
    return {
        "id": uuid.UUID(data["user"]["id"]),
        "access_token": token,
        "headers": {"Authorization": f"Bearer {token}"},
        "user": data["user"],
    }


@pytest.fixture
async def social_user2(async_client: AsyncClient):
    """User 2 fixture."""
    email = f"social_u2_{uuid.uuid4().hex[:8]}@example.com"
    password = "SecurePassword123!"
    res = await async_client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": password, "name": "Diya Sen"},
    )
    assert res.status_code == 201
    data = res.json()["data"]
    token = data["access_token"]
    return {
        "id": uuid.UUID(data["user"]["id"]),
        "access_token": token,
        "headers": {"Authorization": f"Bearer {token}"},
        "user": data["user"],
    }


@pytest.fixture
async def sample_creator():
    """Creator entity fixture."""
    async with AsyncSessionLocal() as session:
        repo = CreatorRepository(session)
        creator = await repo.create(
            name=f"Artist_{uuid.uuid4().hex[:6]}",
            username=f"artist_{uuid.uuid4().hex[:6]}",
            bio="Singer, composer, and producer.",
            avatar_url="https://images.unsplash.com/photo-artist.jpg",
            cover_image_url="https://images.unsplash.com/photo-cover.jpg",
            is_verified=True,
            followers_count=0,
        )
        await session.commit()
        await session.refresh(creator)
        creator_id = creator.id
        creator_name = creator.name

    return {"id": creator_id, "name": creator_name}


@pytest.mark.asyncio
class TestCreatorProfileAndFollowing:
    """Tests for public creator profiles, follow/unfollow lifecycle, concurrency, and privacy."""

    async def test_get_creator_profile_public_success(self, async_client: AsyncClient, sample_creator):
        """Public creator profile returns expected public metadata without private user fields."""
        creator_id = sample_creator["id"]
        res = await async_client.get(f"/api/v1/creators/{creator_id}")
        assert res.status_code == 200
        body = res.json()
        assert body["success"] is True
        data = body["data"]

        assert data["id"] == str(creator_id)
        assert data["name"] == sample_creator["name"]
        assert data["is_verified"] is True
        assert data["followers_count"] == 0
        assert data["is_following"] is None
        assert "popular_tracks" in data
        assert "latest_tracks" in data
        assert "albums" in data
        assert "public_playlists" in data

        # Security check: Ensure no private user fields are leaked
        assert "email" not in data
        assert "hashed_password" not in data
        assert "tokens" not in data
        assert "last_login_at" not in data

    async def test_get_nonexistent_creator_returns_404(self, async_client: AsyncClient):
        """Requesting non-existent creator UUID returns 404 with standard error."""
        random_id = uuid.uuid4()
        res = await async_client.get(f"/api/v1/creators/{random_id}")
        assert res.status_code == 404
        body = res.json()
        assert body["success"] is False
        assert body["error"]["code"] == "NOT_FOUND"

    async def test_follow_and_unfollow_lifecycle(
        self, async_client: AsyncClient, social_user1, sample_creator
    ):
        """User can follow and unfollow a creator; follower counts increment and decrement correctly."""
        creator_id = sample_creator["id"]
        headers = social_user1["headers"]

        # 1. Initially not following
        status_res = await async_client.get(
            f"/api/v1/creators/{creator_id}/follow-status",
            headers=headers,
        )
        assert status_res.status_code == 200
        assert status_res.json()["data"]["is_following"] is False
        assert status_res.json()["data"]["followers_count"] == 0

        # 2. Follow creator
        follow_res = await async_client.post(
            f"/api/v1/creators/{creator_id}/follow",
            headers=headers,
        )
        assert follow_res.status_code == 200
        follow_data = follow_res.json()["data"]
        assert follow_data["is_following"] is True
        assert follow_data["followers_count"] == 1

        # 3. Follow status now reports True
        status_res2 = await async_client.get(
            f"/api/v1/creators/{creator_id}/follow-status",
            headers=headers,
        )
        assert status_res2.status_code == 200
        assert status_res2.json()["data"]["is_following"] is True
        assert status_res2.json()["data"]["followers_count"] == 1

        # 4. Creator profile now reports is_following=True for this user
        prof_res = await async_client.get(
            f"/api/v1/creators/{creator_id}",
            headers=headers,
        )
        assert prof_res.status_code == 200
        assert prof_res.json()["data"]["is_following"] is True
        assert prof_res.json()["data"]["followers_count"] == 1

        # 5. Unfollow creator
        unfollow_res = await async_client.delete(
            f"/api/v1/creators/{creator_id}/follow",
            headers=headers,
        )
        assert unfollow_res.status_code == 200
        unfollow_data = unfollow_res.json()["data"]
        assert unfollow_data["is_following"] is False
        assert unfollow_data["followers_count"] == 0

        # 6. Status now reports False
        status_res3 = await async_client.get(
            f"/api/v1/creators/{creator_id}/follow-status",
            headers=headers,
        )
        assert status_res3.status_code == 200
        assert status_res3.json()["data"]["is_following"] is False
        assert status_res3.json()["data"]["followers_count"] == 0

    async def test_follow_idempotency_prevents_double_increment(
        self, async_client: AsyncClient, social_user1, sample_creator
    ):
        """Repeated follow calls by the same user do not duplicate relations or increment counts twice."""
        creator_id = sample_creator["id"]
        headers = social_user1["headers"]

        # Follow twice
        res1 = await async_client.post(f"/api/v1/creators/{creator_id}/follow", headers=headers)
        assert res1.status_code == 200
        assert res1.json()["data"]["followers_count"] == 1

        res2 = await async_client.post(f"/api/v1/creators/{creator_id}/follow", headers=headers)
        assert res2.status_code == 200
        assert res2.json()["data"]["followers_count"] == 1
        assert res2.json()["data"]["is_following"] is True

        # Unfollow once
        del1 = await async_client.delete(f"/api/v1/creators/{creator_id}/follow", headers=headers)
        assert del1.status_code == 200
        assert del1.json()["data"]["followers_count"] == 0

        # Repeated unfollow does not decrement below 0
        del2 = await async_client.delete(f"/api/v1/creators/{creator_id}/follow", headers=headers)
        assert del2.status_code == 200
        assert del2.json()["data"]["followers_count"] == 0
        assert del2.json()["data"]["is_following"] is False

    async def test_cannot_follow_own_creator_profile(
        self, async_client: AsyncClient, social_user1
    ):
        """User cannot follow their own creator profile."""
        user_id = social_user1["id"]
        headers = social_user1["headers"]

        async with AsyncSessionLocal() as session:
            repo = CreatorRepository(session)
            creator = await repo.create(
                user_id=user_id,
                name="Self Creator",
                followers_count=0,
            )
            await session.commit()
            own_creator_id = creator.id

        res = await async_client.post(
            f"/api/v1/creators/{own_creator_id}/follow",
            headers=headers,
        )
        assert res.status_code == 400
        assert res.json()["error"]["code"] == "SELF_FOLLOW_FORBIDDEN"

    async def test_unauthenticated_follow_rejected(self, async_client: AsyncClient, sample_creator):
        """Following without auth token returns 401."""
        creator_id = sample_creator["id"]
        res = await async_client.post(f"/api/v1/creators/{creator_id}/follow")
        assert res.status_code == 401

    async def test_get_followers_and_following_lists(
        self, async_client: AsyncClient, social_user1, social_user2, sample_creator
    ):
        """Followers and following lists return paginated, accurate lists with proper privacy."""
        creator_id = sample_creator["id"]

        # User 1 follows Creator
        await async_client.post(
            f"/api/v1/creators/{creator_id}/follow",
            headers=social_user1["headers"],
        )

        # User 2 follows Creator
        await async_client.post(
            f"/api/v1/creators/{creator_id}/follow",
            headers=social_user2["headers"],
        )

        # 1. Fetch Creator Followers
        res_followers = await async_client.get(f"/api/v1/creators/{creator_id}/followers?page=1&size=10")
        assert res_followers.status_code == 200
        fol_data = res_followers.json()["data"]
        assert fol_data["total"] == 2
        follower_ids = [item["id"] for item in fol_data["items"]]
        assert str(social_user1["id"]) in follower_ids
        assert str(social_user2["id"]) in follower_ids

        # Verify follower items contain public fields only
        for item in fol_data["items"]:
            assert "name" in item
            assert "followed_at" in item
            assert "email" not in item
            assert "password" not in item

        # 2. Fetch User 1 Following list via /api/v1/users/me/following
        res_following = await async_client.get(
            "/api/v1/users/me/following?page=1&size=10",
            headers=social_user1["headers"],
        )
        assert res_following.status_code == 200
        ing_data = res_following.json()["data"]
        assert ing_data["total"] >= 1
        following_creator_ids = [c["id"] for c in ing_data["items"]]
        assert str(creator_id) in following_creator_ids
        assert all(c["is_following"] is True for c in ing_data["items"])

        # 3. Clean up
        await async_client.delete(
            f"/api/v1/creators/{creator_id}/follow",
            headers=social_user1["headers"],
        )
        await async_client.delete(
            f"/api/v1/creators/{creator_id}/follow",
            headers=social_user2["headers"],
        )

    async def test_search_integration_includes_follow_state(
        self, async_client: AsyncClient, social_user1, sample_creator
    ):
        """Search returns artist cards with accurate followers_count and is_following state."""
        creator_id = sample_creator["id"]
        creator_name = sample_creator["name"]
        headers = social_user1["headers"]

        # Follow creator
        await async_client.post(
            f"/api/v1/creators/{creator_id}/follow",
            headers=headers,
        )

        # Search for creator
        res = await async_client.get(
            f"/api/v1/search?q={creator_name}&type=artists",
            headers=headers,
        )
        assert res.status_code == 200
        artists = res.json()["data"]["artists"]
        matched = next((a for a in artists if a["name"] == creator_name), None)
        assert matched is not None
        assert matched["id"] == str(creator_id)
        assert matched["followers_count"] == 1
        assert matched["is_following"] is True
        assert matched["is_verified"] is True

        # Unfollow and search again
        await async_client.delete(
            f"/api/v1/creators/{creator_id}/follow",
            headers=headers,
        )
        res2 = await async_client.get(
            f"/api/v1/search?q={creator_name}&type=artists",
            headers=headers,
        )
        artists2 = res2.json()["data"]["artists"]
        matched2 = next((a for a in artists2 if a["name"] == creator_name), None)
        assert matched2 is not None
        assert matched2["followers_count"] == 0
        assert matched2["is_following"] is False
