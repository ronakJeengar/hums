import io
import uuid
import pytest
from httpx import AsyncClient
from PIL import Image


def create_test_image_bytes(format: str = "PNG", size: tuple = (100, 100), color: str = "red") -> bytes:
    """Helper to generate a valid in-memory image for upload testing."""
    image = Image.new("RGB", size, color=color)
    byte_io = io.BytesIO()
    image.save(byte_io, format=format)
    return byte_io.getvalue()


@pytest.fixture
async def registered_user_tokens(async_client: AsyncClient):
    """Registers and logs in a test user, returning access token and headers."""
    email = f"profile_test_{uuid.uuid4().hex[:8]}@example.com"
    password = "SecurePassword123!"
    register_res = await async_client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": password, "name": "Profile Tester"},
    )
    assert register_res.status_code == 201
    data = register_res.json()["data"]
    token = data["access_token"]
    return {
        "access_token": token,
        "headers": {"Authorization": f"Bearer {token}"},
        "user": data["user"],
        "email": email,
        "password": password,
    }


@pytest.fixture
async def second_user_tokens(async_client: AsyncClient):
    """Registers a second user for multi-user isolation tests."""
    email = f"second_user_{uuid.uuid4().hex[:8]}@example.com"
    password = "SecurePassword123!"
    register_res = await async_client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": password, "name": "Second User"},
    )
    assert register_res.status_code == 201
    data = register_res.json()["data"]
    token = data["access_token"]
    return {
        "access_token": token,
        "headers": {"Authorization": f"Bearer {token}"},
        "user": data["user"],
        "email": email,
    }


class TestProfileRetrieval:
    async def test_get_profile_authenticated(self, async_client: AsyncClient, registered_user_tokens):
        headers = registered_user_tokens["headers"]
        response = await async_client.get("/api/v1/profile", headers=headers)
        assert response.status_code == 200
        body = response.json()
        assert body["success"] is True
        profile = body["data"]
        assert profile["email"] == registered_user_tokens["email"]
        assert profile["name"] == "Profile Tester"
        assert "password" not in profile
        assert "hashed_password" not in profile
        assert "refresh_tokens" not in profile

    async def test_get_profile_unauthenticated(self, async_client: AsyncClient):
        response = await async_client.get("/api/v1/profile")
        assert response.status_code == 401
        assert response.json()["success"] is False


class TestProfileUpdate:
    async def test_update_name_success(self, async_client: AsyncClient, registered_user_tokens):
        headers = registered_user_tokens["headers"]
        response = await async_client.patch(
            "/api/v1/profile",
            headers=headers,
            json={"name": "Updated Profile Name"},
        )
        assert response.status_code == 200
        body = response.json()
        assert body["data"]["name"] == "Updated Profile Name"

    async def test_update_email_success(self, async_client: AsyncClient, registered_user_tokens):
        headers = registered_user_tokens["headers"]
        new_email = f"new_email_{uuid.uuid4().hex[:8]}@example.com"
        response = await async_client.patch(
            "/api/v1/profile",
            headers=headers,
            json={"email": new_email},
        )
        assert response.status_code == 200
        body = response.json()
        assert body["data"]["email"] == new_email

    async def test_update_email_duplicate_rejected(
        self, async_client: AsyncClient, registered_user_tokens, second_user_tokens
    ):
        headers = registered_user_tokens["headers"]
        # Try to take second user's email
        response = await async_client.patch(
            "/api/v1/profile",
            headers=headers,
            json={"email": second_user_tokens["email"]},
        )
        assert response.status_code == 409
        body = response.json()
        assert body["error"]["code"] == "EMAIL_ALREADY_EXISTS"

    async def test_update_bio_success(self, async_client: AsyncClient, registered_user_tokens):
        headers = registered_user_tokens["headers"]
        bio_text = "Audio enthusiast, podcast listener, and music creator."
        response = await async_client.patch(
            "/api/v1/profile",
            headers=headers,
            json={"bio": bio_text},
        )
        assert response.status_code == 200
        assert response.json()["data"]["bio"] == bio_text

    async def test_partial_update_preserves_other_fields(
        self, async_client: AsyncClient, registered_user_tokens
    ):
        headers = registered_user_tokens["headers"]
        # Update name first
        await async_client.patch("/api/v1/profile", headers=headers, json={"name": "Alice Wonderland"})
        # Update only bio
        response = await async_client.patch("/api/v1/profile", headers=headers, json={"bio": "New Bio"})
        assert response.status_code == 200
        data = response.json()["data"]
        assert data["name"] == "Alice Wonderland"
        assert data["bio"] == "New Bio"

    async def test_invalid_name_too_short(self, async_client: AsyncClient, registered_user_tokens):
        headers = registered_user_tokens["headers"]
        response = await async_client.patch(
            "/api/v1/profile",
            headers=headers,
            json={"name": "a"},
        )
        assert response.status_code in (400, 422)

    async def test_bio_too_long(self, async_client: AsyncClient, registered_user_tokens):
        headers = registered_user_tokens["headers"]
        response = await async_client.patch(
            "/api/v1/profile",
            headers=headers,
            json={"bio": "x" * 501},
        )
        assert response.status_code in (400, 422)


class TestAvatarManagement:
    async def test_upload_avatar_success(self, async_client: AsyncClient, registered_user_tokens):
        headers = registered_user_tokens["headers"]
        img_bytes = create_test_image_bytes(format="PNG", size=(120, 120), color="blue")

        response = await async_client.post(
            "/api/v1/profile/avatar",
            headers=headers,
            files={"file": ("avatar.png", img_bytes, "image/png")},
        )
        assert response.status_code == 200
        body = response.json()
        assert body["success"] is True
        avatar_url = body["data"]["avatar_url"]
        assert avatar_url is not None
        assert "/avatars/" in avatar_url

    async def test_upload_avatar_unsupported_mime(self, async_client: AsyncClient, registered_user_tokens):
        headers = registered_user_tokens["headers"]
        response = await async_client.post(
            "/api/v1/profile/avatar",
            headers=headers,
            files={"file": ("notes.txt", b"not an image", "text/plain")},
        )
        assert response.status_code == 400
        body = response.json()
        assert body["error"]["code"] == "UNSUPPORTED_IMAGE_TYPE"

    async def test_upload_avatar_corrupt_image(self, async_client: AsyncClient, registered_user_tokens):
        headers = registered_user_tokens["headers"]
        # Pass image/png header but corrupted garbage bytes
        response = await async_client.post(
            "/api/v1/profile/avatar",
            headers=headers,
            files={"file": ("avatar.png", b"GIF89a corrupt bytes", "image/png")},
        )
        assert response.status_code == 400
        body = response.json()
        assert body["error"]["code"] in ("INVALID_IMAGE", "UNSUPPORTED_IMAGE_TYPE")

    async def test_upload_avatar_oversized(self, async_client: AsyncClient, registered_user_tokens):
        headers = registered_user_tokens["headers"]
        # > 5MB file
        large_bytes = b"0" * (6 * 1024 * 1024)
        response = await async_client.post(
            "/api/v1/profile/avatar",
            headers=headers,
            files={"file": ("large.jpg", large_bytes, "image/jpeg")},
        )
        assert response.status_code == 400
        body = response.json()
        assert body["error"]["code"] == "IMAGE_TOO_LARGE"

    async def test_replace_and_remove_avatar(self, async_client: AsyncClient, registered_user_tokens):
        headers = registered_user_tokens["headers"]

        # 1. Upload first avatar
        img1 = create_test_image_bytes(format="JPEG", size=(80, 80), color="green")
        res1 = await async_client.post(
            "/api/v1/profile/avatar",
            headers=headers,
            files={"file": ("first.jpg", img1, "image/jpeg")},
        )
        assert res1.status_code == 200
        url1 = res1.json()["data"]["avatar_url"]

        # 2. Upload replacement avatar
        img2 = create_test_image_bytes(format="PNG", size=(90, 90), color="yellow")
        res2 = await async_client.post(
            "/api/v1/profile/avatar",
            headers=headers,
            files={"file": ("second.png", img2, "image/png")},
        )
        assert res2.status_code == 200
        url2 = res2.json()["data"]["avatar_url"]
        assert url1 != url2

        # 3. Remove avatar
        res3 = await async_client.delete("/api/v1/profile/avatar", headers=headers)
        assert res3.status_code == 200
        assert res3.json()["data"]["avatar_url"] is None

        # 4. Remove avatar again when none exists (idempotent / safe)
        res4 = await async_client.delete("/api/v1/profile/avatar", headers=headers)
        assert res4.status_code == 200
        assert res4.json()["data"]["avatar_url"] is None
