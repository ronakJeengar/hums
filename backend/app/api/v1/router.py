from fastapi import APIRouter
from app.api.v1.endpoints import audio, auth, health, profile, users

v1_router = APIRouter()
v1_router.include_router(health.router)
v1_router.include_router(auth.router)
v1_router.include_router(users.router)
v1_router.include_router(profile.router, prefix="/profile", tags=["profile"])
v1_router.include_router(audio.router, prefix="/audio", tags=["audio"])


