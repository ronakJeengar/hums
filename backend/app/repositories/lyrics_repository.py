import uuid
from typing import List, Optional
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.db.models.lyrics import LyricLine, Lyrics, LyricsStatus


class LyricsRepository:
    """Repository managing persistent storage of track lyrics and lyric lines."""

    def __init__(self, session: AsyncSession):
        self.session = session

    async def get_by_track_id(self, track_id: uuid.UUID) -> Optional[Lyrics]:
        """Retrieves lyrics for a track, including all ordered lyric lines."""
        stmt = (
            select(Lyrics)
            .where(Lyrics.track_id == track_id)
            .options(selectinload(Lyrics.lines))
            .execution_options(populate_existing=True)
        )
        result = await self.session.execute(stmt)
        return result.scalars().first()

    async def create_or_update(
        self,
        track_id: uuid.UUID,
        status: str,
        source: str,
        is_synchronized: bool,
        text: Optional[str] = None,
        language: Optional[str] = None,
        model: Optional[str] = None,
        version: str = "v1",
        error_message: Optional[str] = None,
        lines_data: Optional[List[dict]] = None,
    ) -> Lyrics:
        """
        Creates or updates lyrics for a track.
        If existing lyrics exist, updates fields and replaces lyric lines atomically.
        """
        lyrics = await self.get_by_track_id(track_id)

        if not lyrics:
            new_lines = []
            if lines_data is not None:
                new_lines = [
                    LyricLine(
                        sequence=item["sequence"],
                        start_ms=item["start_ms"],
                        end_ms=item.get("end_ms"),
                        text=item["text"],
                    )
                    for item in lines_data
                ]
            lyrics = Lyrics(
                track_id=track_id,
                status=status,
                source=source,
                is_synchronized=is_synchronized,
                text=text,
                language=language,
                model=model,
                version=version,
                error_message=error_message,
                lines=new_lines,
            )
            self.session.add(lyrics)
            await self.session.flush()
        else:
            lyrics.status = status
            lyrics.source = source
            lyrics.is_synchronized = is_synchronized
            lyrics.text = text
            lyrics.language = language
            lyrics.model = model
            lyrics.version = version
            lyrics.error_message = error_message

            if lines_data is not None:
                await self.session.execute(
                    delete(LyricLine).where(LyricLine.lyrics_id == lyrics.id)
                )
                for item in lines_data:
                    self.session.add(
                        LyricLine(
                            lyrics_id=lyrics.id,
                            sequence=item["sequence"],
                            start_ms=item["start_ms"],
                            end_ms=item.get("end_ms"),
                            text=item["text"],
                        )
                    )

            await self.session.flush()

        refreshed = await self.get_by_track_id(track_id)
        return refreshed or lyrics

    async def update_status(
        self,
        lyrics: Lyrics,
        status: str,
        error_message: Optional[str] = None,
    ) -> Lyrics:
        """Updates status and error_message for existing lyrics record."""
        lyrics.status = status
        lyrics.error_message = error_message
        await self.session.flush()
        refreshed = await self.get_by_track_id(lyrics.track_id)
        return refreshed or lyrics

    async def delete_by_track_id(self, track_id: uuid.UUID) -> bool:
        """Deletes lyrics and cascading lines for a track."""
        lyrics = await self.get_by_track_id(track_id)
        if not lyrics:
            return False
        await self.session.delete(lyrics)
        await self.session.flush()
        return True
