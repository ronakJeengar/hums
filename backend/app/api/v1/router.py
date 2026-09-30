from fastapi import APIRouter
from app.api.v1.endpoints import (
    audio,
    auth,
    creators,
    health,
    library,
    likes,
    notifications,
    playback,
    playback_settings,
    playlists,
    profile,
    recommendations,
    search,
    telemetry,
    users,
)

v1_router = APIRouter()
v1_router.include_router(health.router)
v1_router.include_router(auth.router)
v1_router.include_router(users.router)
v1_router.include_router(creators.router, prefix="/creators", tags=["creators"])
v1_router.include_router(profile.router, prefix="/profile", tags=["profile"])
v1_router.include_router(audio.router, prefix="/audio", tags=["audio"])
v1_router.include_router(audio.router, tags=["tracks_alias"])
v1_router.include_router(likes.router, prefix="/tracks", tags=["likes"])
v1_router.include_router(likes.router, prefix="/audio/tracks", tags=["audio_likes_alias"])
v1_router.include_router(library.router, prefix="/library", tags=["library"])
v1_router.include_router(playlists.router, prefix="/playlists", tags=["playlists"])
v1_router.include_router(search.router, prefix="/search", tags=["search"])
v1_router.include_router(playback.router, prefix="/playback", tags=["playback"])
v1_router.include_router(playback.history_alias_router, tags=["history"])
v1_router.include_router(playback_settings.router, prefix="/settings", tags=["settings"])
v1_router.include_router(telemetry.router)
v1_router.include_router(notifications.router, prefix="/notifications", tags=["notifications"])
v1_router.include_router(recommendations.router, prefix="/recommendations", tags=["recommendations"])

