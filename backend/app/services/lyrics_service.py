import json
import logging
import uuid
from typing import Optional
from redis.asyncio import Redis

from app.ai.gemini_lyrics_client import GeminiLyricsClient, sanitize_lyric_text
from app.core.errors import AppException, BadRequestError, ForbiddenError, NotFoundError
from app.db.models.audio import Track
from app.db.models.lyrics import LyricLine, Lyrics, LyricsSource, LyricsStatus
from app.repositories.audio_repository import TrackRepository
from app.repositories.lyrics_repository import LyricsRepository
from app.schemas.lyrics import (
    LyricLineItem,
    LyricsCreateRequest,
    LyricsResponse,
)

logger = logging.getLogger("hums.services.lyrics")

LYRICS_CACHE_TTL = 3600  # 1 hour


class LyricsService:
    """Service orchestrating track lyrics retrieval, AI generation, validation, and caching."""

    def __init__(
        self,
        lyrics_repo: LyricsRepository,
        track_repo: TrackRepository,
        gemini_client: Optional[GeminiLyricsClient] = None,
        redis_client: Optional[Redis] = None,
    ):
        self.lyrics_repo = lyrics_repo
        self.track_repo = track_repo
        self.gemini_client = gemini_client or GeminiLyricsClient()
        self.redis = redis_client

    async def get_lyrics(self, track_id: uuid.UUID) -> LyricsResponse:
        """
        Retrieves lyrics for a track, checking Redis cache first.
        Validates track existence and readiness.
        """
        cache_key = f"lyrics:{track_id}"

        # 1. Check Redis cache
        if self.redis:
            try:
                cached_bytes = await self.redis.get(cache_key)
                if cached_bytes:
                    data = json.loads(cached_bytes.decode("utf-8"))
                    return LyricsResponse.model_validate(data)
            except Exception as e:
                logger.warning(f"Redis get failed for lyrics:{track_id}: {e}")

        # 2. Validate Track exists and is playable
        track = await self.track_repo.get_by_id(track_id)
        if not track:
            raise NotFoundError("Track not found", details={"track_id": str(track_id)})

        if track.status != "READY":
            raise AppException(
                f"Track is not ready for playback (current status: {track.status})",
                code="TRACK_NOT_READY",
                status_code=409,
            )

        # 3. Query PostgreSQL for Lyrics record
        lyrics = await self.lyrics_repo.get_by_track_id(track_id)

        if not lyrics:
            response = LyricsResponse(
                track_id=track_id,
                status=LyricsStatus.UNAVAILABLE,
                source=LyricsSource.AI_GENERATED,
                is_synchronized=False,
                lines=[],
            )
            return response

        response = self._entity_to_response(lyrics)

        # 4. Populate Redis cache if status is terminal (COMPLETED, UNAVAILABLE, FAILED)
        if self.redis and lyrics.status in (LyricsStatus.COMPLETED, LyricsStatus.UNAVAILABLE):
            try:
                await self.redis.set(
                    cache_key,
                    response.model_dump_json(),
                    ex=LYRICS_CACHE_TTL,
                )
            except Exception as e:
                logger.warning(f"Redis set failed for lyrics:{track_id}: {e}")

        return response

    async def generate_lyrics(self, track_id: uuid.UUID) -> LyricsResponse:
        """
        Runs asynchronous AI lyrics generation for a READY track via Gemini.
        Validates and persists output, updating status and evicting caches.
        """
        track = await self.track_repo.get_by_id(track_id)
        if not track:
            logger.error(f"Cannot generate lyrics for non-existent track: {track_id}")
            raise NotFoundError("Track not found", details={"track_id": str(track_id)})

        if track.status != "READY":
            logger.warning(f"Cannot generate lyrics for track {track_id} in status {track.status}")
            raise AppException("Track is not ready", code="TRACK_NOT_READY", status_code=409)

        # Transition status to PROCESSING
        lyrics = await self.lyrics_repo.create_or_update(
            track_id=track_id,
            status=LyricsStatus.PROCESSING,
            source=LyricsSource.AI_GENERATED,
            is_synchronized=False,
            model=self.gemini_client.model,
            version=self.gemini_client.version,
        )
        await self._invalidate_cache(track_id)

        ai_result = await self.gemini_client.generate_lyrics(
            title=track.title,
            artist_name=track.artist_name,
            album_name=track.album_name,
            genre=track.genre,
            duration_seconds=track.duration_seconds,
            description=track.description,
        )

        if not ai_result or (not ai_result.get("plain_text") and not ai_result.get("lines")):
            logger.info(f"AI lyrics unavailable or generation failed for track {track_id}")
            lyrics = await self.lyrics_repo.create_or_update(
                track_id=track_id,
                status=LyricsStatus.UNAVAILABLE,
                source=LyricsSource.AI_GENERATED,
                is_synchronized=False,
                error_message="Lyrics could not be generated for this track",
                model=self.gemini_client.model,
                version=self.gemini_client.version,
            )
            await self._invalidate_cache(track_id)
            return self._entity_to_response(lyrics)

        # Successful generation
        lyrics = await self.lyrics_repo.create_or_update(
            track_id=track_id,
            status=LyricsStatus.COMPLETED,
            source=LyricsSource.AI_GENERATED,
            is_synchronized=ai_result["is_synchronized"],
            language=ai_result.get("language"),
            text=ai_result.get("plain_text"),
            model=self.gemini_client.model,
            version=self.gemini_client.version,
            lines_data=ai_result.get("lines"),
        )
        await self._invalidate_cache(track_id)
        logger.info(f"Successfully generated lyrics for track {track_id} (synchronized={lyrics.is_synchronized})")
        return self._entity_to_response(lyrics)

    async def save_manual_lyrics(
        self,
        track_id: uuid.UUID,
        user_id: uuid.UUID,
        request: LyricsCreateRequest,
    ) -> LyricsResponse:
        """
        Allows track owners to upload plain or synchronized lyrics with validation.
        """
        track = await self.track_repo.get_by_id(track_id)
        if not track:
            raise NotFoundError("Track not found", details={"track_id": str(track_id)})

        if track.owner_id != user_id:
            raise ForbiddenError("Only the track owner can upload lyrics for this track")

        # Validate line timings if synchronized
        lines_data = None
        is_synchronized = request.is_synchronized

        if request.lines:
            last_start_ms = -1
            clean_lines = []

            for i, line in enumerate(request.lines):
                text = sanitize_lyric_text(line.text)
                if not text:
                    continue

                if line.start_ms < 0:
                    raise BadRequestError(
                        f"Line {i} has negative start_ms: {line.start_ms}",
                        code="INVALID_LYRIC_TIMESTAMPS",
                    )

                if line.start_ms < last_start_ms:
                    raise BadRequestError(
                        f"Line {i} timestamp ({line.start_ms}ms) occurs before previous line ({last_start_ms}ms)",
                        code="INVALID_LYRIC_TIMESTAMPS",
                    )

                if line.end_ms is not None and line.end_ms < line.start_ms:
                    raise BadRequestError(
                        f"Line {i} end_ms ({line.end_ms}ms) is less than start_ms ({line.start_ms}ms)",
                        code="INVALID_LYRIC_TIMESTAMPS",
                    )

                last_start_ms = line.start_ms
                clean_lines.append({
                    "sequence": i,
                    "start_ms": line.start_ms,
                    "end_ms": line.end_ms,
                    "text": text,
                })

            lines_data = clean_lines
            if not lines_data:
                is_synchronized = False

        plain_text = sanitize_lyric_text(request.text or "")
        if not plain_text and lines_data:
            plain_text = "\n".join(l["text"] for l in lines_data)

        if not plain_text and not lines_data:
            raise BadRequestError(
                "Either lyric text or synchronized lines must be provided",
                code="EMPTY_LYRICS_DATA",
            )

        lyrics = await self.lyrics_repo.create_or_update(
            track_id=track_id,
            status=LyricsStatus.COMPLETED,
            source=LyricsSource.MANUAL,
            is_synchronized=is_synchronized,
            language=request.language or "en",
            text=plain_text,
            lines_data=lines_data,
        )

        await self._invalidate_cache(track_id)
        return self._entity_to_response(lyrics)

    async def _invalidate_cache(self, track_id: uuid.UUID) -> None:
        """Evicts Redis cache entry for the given track lyrics."""
        if self.redis:
            try:
                await self.redis.delete(f"lyrics:{track_id}")
            except Exception as e:
                logger.warning(f"Redis delete failed for lyrics:{track_id}: {e}")

    def _entity_to_response(self, lyrics: Lyrics) -> LyricsResponse:
        """Maps SQLAlchemy entity to Pydantic LyricsResponse."""
        lines = [
            LyricLineItem(
                id=line.id,
                sequence=line.sequence,
                start_ms=line.start_ms,
                end_ms=line.end_ms,
                text=line.text,
            )
            for line in (lyrics.lines or [])
        ]
        return LyricsResponse(
            id=lyrics.id,
            track_id=lyrics.track_id,
            status=lyrics.status,
            language=lyrics.language,
            source=lyrics.source,
            is_synchronized=lyrics.is_synchronized,
            text=lyrics.text,
            lines=lines,
            model=lyrics.model,
            version=lyrics.version,
            error_message=lyrics.error_message,
            updated_at=lyrics.updated_at,
        )
