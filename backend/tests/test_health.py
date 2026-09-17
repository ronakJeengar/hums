import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_root_health_endpoint(async_client: AsyncClient):
    """Verifies shallow root liveness endpoint."""
    response = await async_client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert data["app"] == "Hums"


@pytest.mark.asyncio
async def test_deep_system_health_endpoint(async_client: AsyncClient):
    """Verifies deep health check endpoint validating PostgreSQL and Redis connectivity."""
    response = await async_client.get("/api/v1/health")
    assert response.status_code == 200
    json_data = response.json()
    assert json_data["success"] is True
    assert "data" in json_data
    assert json_data["data"]["status"] == "healthy"
    assert json_data["data"]["services"]["database"] == "connected"
    assert json_data["data"]["services"]["redis"] == "connected"
    assert "timestamp" in json_data["meta"]
    assert json_data["meta"]["version"] == "1.0.0"
