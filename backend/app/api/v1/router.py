from fastapi import APIRouter
from app.api.v1.endpoints import audio, auth, health, playback, playlists, profile, telemetry, users

v1_router = APIRouter()
v1_router.include_router(health.router)
v1_router.include_router(auth.router)
v1_router.include_router(users.router)
v1_router.include_router(profile.router, prefix="/profile", tags=["profile"])
v1_router.include_router(audio.router, prefix="/audio", tags=["audio"])
v1_router.include_router(audio.router, tags=["tracks_alias"])
v1_router.include_router(playlists.router, prefix="/playlists", tags=["playlists"])
v1_router.include_router(playback.router, prefix="/playback", tags=["playback"])
v1_router.include_router(playback.history_alias_router, tags=["history"])
v1_router.include_router(telemetry.router)

