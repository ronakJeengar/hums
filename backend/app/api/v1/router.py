from fastapi import APIRouter
from app.api.v1.endpoints import auth, health, users

v1_router = APIRouter()
v1_router.include_router(health.router)
v1_router.include_router(auth.router)
v1_router.include_router(users.router)
