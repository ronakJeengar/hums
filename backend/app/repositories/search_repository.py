import uuid
from typing import Any

from sqlalchemy import and_, case, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.db.models.audio import Track
from app.db.models.playlist import Playlist
from app.db.models.user import User


class SearchRepository:
    """Repository handling full-text, substring, and trigram-ranked queries across Hums catalog."""

    def __init__(self, session: AsyncSession):
        self.session = session

    @staticmethod
    def _escape_like_pattern(text: str) -> str:
        """Escapes special SQL LIKE wildcards (% and _) to avoid unintended wildcard matching."""
        return text.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")

    async def search_tracks(
        self,
        query_str: str,
        limit: int = 20,
        skip: int = 0,
    ) -> tuple[list[Track], int]:
        """
        Searches audio tracks using exact, prefix, substring, and pg_trgm word_similarity matching.
        Strictly enforces status == 'READY'.
        """
        clean_q = query_str.strip()
        if not clean_q:
            return [], 0

        exact_q = clean_q.lower()
        escaped_q = self._escape_like_pattern(clean_q)
        prefix_q = f"{escaped_q}%"
        substr_q = f"%{escaped_q}%"
        raw_q = clean_q

        # Relevance ranking expression
        score_expr = (
            # Exact title match (highest priority)
            case((func.lower(Track.title) == exact_q, 100.0), else_=0.0)
            + case((func.lower(func.coalesce(Track.artist_name, "")) == exact_q, 80.0), else_=0.0)
            # Prefix matches
            + case((Track.title.ilike(prefix_q), 50.0), else_=0.0)
            + case((func.coalesce(Track.artist_name, "").ilike(prefix_q), 40.0), else_=0.0)
            # Substring matches
            + case((Track.title.ilike(substr_q), 25.0), else_=0.0)
            + case((func.coalesce(Track.artist_name, "").ilike(substr_q), 20.0), else_=0.0)
            + case((func.coalesce(Track.album_name, "").ilike(substr_q), 15.0), else_=0.0)
            + case((func.coalesce(Track.genre, "").ilike(substr_q), 10.0), else_=0.0)
            # Trigram word similarity bonus for typo resilience
            + (func.word_similarity(raw_q, Track.title) * 20.0)
            + (func.word_similarity(raw_q, func.coalesce(Track.artist_name, "")) * 15.0)
        )

        match_cond = and_(
            Track.status == "READY",
            or_(
                Track.title.ilike(substr_q),
                func.coalesce(Track.artist_name, "").ilike(substr_q),
                func.coalesce(Track.album_name, "").ilike(substr_q),
                func.coalesce(Track.genre, "").ilike(substr_q),
                func.word_similarity(raw_q, Track.title) > 0.35,
                func.word_similarity(raw_q, func.coalesce(Track.artist_name, "")) > 0.35,
            ),
        )

        # Count total matching tracks
        count_stmt = select(func.count(Track.id)).where(match_cond)
        count_res = await self.session.execute(count_stmt)
        total_count = count_res.scalar() or 0

        if total_count == 0:
            return [], 0

        # Query tracks with ranking order and deterministic tie-breaker
        query_stmt = (
            select(Track)
            .where(match_cond)
            .order_by(score_expr.desc(), Track.created_at.desc(), Track.id.desc())
            .offset(skip)
            .limit(limit)
        )
        res = await self.session.execute(query_stmt)
        tracks = list(res.scalars().all())
        return tracks, total_count

    async def search_playlists(
        self,
        query_str: str,
        current_user_id: uuid.UUID | None = None,
        limit: int = 20,
        skip: int = 0,
    ) -> tuple[list[tuple[Playlist, int]], int]:
        """
        Searches playlists by name and description with visibility filtering:
        is_public == True OR owner_id == current_user_id.
        """
        clean_q = query_str.strip()
        if not clean_q:
            return [], 0

        exact_q = clean_q.lower()
        escaped_q = self._escape_like_pattern(clean_q)
        prefix_q = f"{escaped_q}%"
        substr_q = f"%{escaped_q}%"
        raw_q = clean_q

        # Privacy visibility enforcement
        if current_user_id is not None:
            vis_cond = or_(Playlist.is_public == True, Playlist.owner_id == current_user_id)
        else:
            vis_cond = Playlist.is_public == True

        # Relevance ranking expression
        score_expr = (
            case((func.lower(Playlist.name) == exact_q, 100.0), else_=0.0)
            + case((Playlist.name.ilike(prefix_q), 50.0), else_=0.0)
            + case((Playlist.name.ilike(substr_q), 25.0), else_=0.0)
            + case((func.coalesce(Playlist.description, "").ilike(substr_q), 10.0), else_=0.0)
            + (func.word_similarity(raw_q, Playlist.name) * 20.0)
        )

        match_cond = and_(
            vis_cond,
            or_(
                Playlist.name.ilike(substr_q),
                func.coalesce(Playlist.description, "").ilike(substr_q),
                func.word_similarity(raw_q, Playlist.name) > 0.35,
            ),
        )

        # Count total matching playlists
        count_stmt = select(func.count(Playlist.id)).where(match_cond)
        count_res = await self.session.execute(count_stmt)
        total_count = count_res.scalar() or 0

        if total_count == 0:
            return [], 0

        # Query playlists with preloaded tracks for count and deterministic tie-breaker
        query_stmt = (
            select(Playlist)
            .options(selectinload(Playlist.playlist_tracks))
            .where(match_cond)
            .order_by(score_expr.desc(), Playlist.created_at.desc(), Playlist.id.desc())
            .offset(skip)
            .limit(limit)
        )
        res = await self.session.execute(query_stmt)
        playlists = list(res.scalars().all())

        results = [(p, len(p.playlist_tracks)) for p in playlists]
        return results, total_count

    async def search_artists(
        self,
        query_str: str,
        limit: int = 20,
        skip: int = 0,
    ) -> tuple[list[dict[str, Any]], int]:
        """
        Searches creators and artists from registered users and track artist metadata.
        Aggregates track counts for each artist entity.
        """
        clean_q = query_str.strip()
        if not clean_q:
            return [], 0

        exact_q = clean_q.lower()
        escaped_q = self._escape_like_pattern(clean_q)
        prefix_q = f"{escaped_q}%"
        substr_q = f"%{escaped_q}%"
        raw_q = clean_q

        # Subquery for user track count (READY tracks only)
        user_track_count_subq = (
            select(func.count(Track.id))
            .where(Track.owner_id == User.id, Track.status == "READY")
            .scalar_subquery()
        )

        user_score_expr = (
            case((func.lower(func.coalesce(User.full_name, "")) == exact_q, 100.0), else_=0.0)
            + case((func.lower(func.coalesce(User.username, "")) == exact_q, 90.0), else_=0.0)
            + case((func.coalesce(User.full_name, "").ilike(prefix_q), 50.0), else_=0.0)
            + case((func.coalesce(User.username, "").ilike(prefix_q), 45.0), else_=0.0)
            + case((func.coalesce(User.full_name, "").ilike(substr_q), 25.0), else_=0.0)
            + case((func.coalesce(User.username, "").ilike(substr_q), 20.0), else_=0.0)
            + (func.word_similarity(raw_q, func.coalesce(User.full_name, "")) * 20.0)
            + (func.word_similarity(raw_q, func.coalesce(User.username, "")) * 15.0)
        )

        user_match_cond = and_(
            User.is_active == True,
            or_(
                func.coalesce(User.full_name, "").ilike(substr_q),
                func.coalesce(User.username, "").ilike(substr_q),
                func.word_similarity(raw_q, func.coalesce(User.full_name, "")) > 0.35,
                func.word_similarity(raw_q, func.coalesce(User.username, "")) > 0.35,
            ),
        )

        user_stmt = (
            select(
                User,
                user_track_count_subq.label("track_count"),
                user_score_expr.label("score"),
            )
            .where(user_match_cond)
            .order_by(user_score_expr.desc(), User.id.desc())
        )
        user_res = await self.session.execute(user_stmt)
        user_rows = user_res.all()

        artists_list: list[dict[str, Any]] = []
        seen_names = set()

        for user, track_count, score in user_rows:
            name = user.full_name or user.username or "Unknown Artist"
            seen_names.add(name.strip().lower())
            artists_list.append({
                "id": str(user.id),
                "name": name,
                "username": user.username,
                "avatar_url": user.avatar_url,
                "bio": user.bio,
                "track_count": track_count or 0,
                "_score": float(score),
            })

        # Also search distinct artist_names in tracks table
        track_artist_score_expr = (
            case((func.lower(Track.artist_name) == exact_q, 95.0), else_=0.0)
            + case((Track.artist_name.ilike(prefix_q), 45.0), else_=0.0)
            + case((Track.artist_name.ilike(substr_q), 22.0), else_=0.0)
            + (func.word_similarity(raw_q, Track.artist_name) * 18.0)
        )

        track_artist_match_cond = and_(
            Track.status == "READY",
            Track.artist_name.isnot(None),
            Track.artist_name != "",
            or_(
                Track.artist_name.ilike(substr_q),
                func.word_similarity(raw_q, Track.artist_name) > 0.35,
            ),
        )

        track_artist_stmt = (
            select(
                Track.artist_name,
                func.count(Track.id).label("track_count"),
                track_artist_score_expr.label("score"),
            )
            .where(track_artist_match_cond)
            .group_by(Track.artist_name)
            .order_by(track_artist_score_expr.desc())
        )
        track_artist_res = await self.session.execute(track_artist_stmt)
        track_artist_rows = track_artist_res.all()

        for artist_name, count, score in track_artist_rows:
            lower_name = artist_name.strip().lower()
            if lower_name not in seen_names:
                seen_names.add(lower_name)
                artist_id = f"artist_{uuid.uuid5(uuid.NAMESPACE_DNS, lower_name)}"
                artists_list.append({
                    "id": artist_id,
                    "name": artist_name.strip(),
                    "username": None,
                    "avatar_url": None,
                    "bio": None,
                    "track_count": count or 0,
                    "_score": float(score),
                })

        # Sort combined results by score descending with id as deterministic tie-breaker
        artists_list.sort(key=lambda a: (a["_score"], a["id"]), reverse=True)
        total_count = len(artists_list)

        # Slice for pagination
        paginated_artists = artists_list[skip : skip + limit]
        for a in paginated_artists:
            a.pop("_score", None)

        return paginated_artists, total_count

    async def search_albums(
        self,
        query_str: str,
        limit: int = 20,
        skip: int = 0,
    ) -> tuple[list[dict[str, Any]], int]:
        """
        Searches distinct music albums based on Track.album_name with track counts.
        """
        clean_q = query_str.strip()
        if not clean_q:
            return [], 0

        exact_q = clean_q.lower()
        escaped_q = self._escape_like_pattern(clean_q)
        prefix_q = f"{escaped_q}%"
        substr_q = f"%{escaped_q}%"
        raw_q = clean_q

        album_score_expr = (
            case((func.lower(Track.album_name) == exact_q, 100.0), else_=0.0)
            + case((Track.album_name.ilike(prefix_q), 50.0), else_=0.0)
            + case((Track.album_name.ilike(substr_q), 25.0), else_=0.0)
            + case((func.coalesce(Track.artist_name, "").ilike(substr_q), 15.0), else_=0.0)
            + (func.word_similarity(raw_q, Track.album_name) * 20.0)
        )

        album_match_cond = and_(
            Track.status == "READY",
            Track.album_name.isnot(None),
            Track.album_name != "",
            or_(
                Track.album_name.ilike(substr_q),
                func.coalesce(Track.artist_name, "").ilike(substr_q),
                func.word_similarity(raw_q, Track.album_name) > 0.35,
            ),
        )

        album_stmt = (
            select(
                Track.album_name,
                Track.artist_name,
                func.count(Track.id).label("track_count"),
                album_score_expr.label("score"),
            )
            .where(album_match_cond)
            .group_by(Track.album_name, Track.artist_name)
            .order_by(album_score_expr.desc(), Track.album_name.asc())
        )
        res = await self.session.execute(album_stmt)
        rows = res.all()

        albums_list: list[dict[str, Any]] = []
        for album_name, artist_name, count, score in rows:
            lower_name = album_name.strip().lower()
            album_id = f"album_{uuid.uuid5(uuid.NAMESPACE_DNS, lower_name)}"
            albums_list.append({
                "id": album_id,
                "title": album_name.strip(),
                "artist_name": artist_name.strip() if artist_name else None,
                "track_count": count or 0,
                "cover_image_key": None,
                "cover_image_url": None,
                "_score": float(score),
            })

        total_count = len(albums_list)
        paginated = albums_list[skip : skip + limit]
        for a in paginated:
            a.pop("_score", None)

        return paginated, total_count

    async def get_suggestions(
        self,
        query_str: str,
        limit: int = 8,
        current_user_id: uuid.UUID | None = None,
    ) -> list[str]:
        """
        Returns rapid, ranked autocomplete suggestions across tracks, artists, albums, and playlists.
        """
        clean_q = query_str.strip()
        if not clean_q or len(clean_q) < 1:
            return []

        escaped_q = self._escape_like_pattern(clean_q)
        prefix_q = f"{escaped_q}%"
        substr_q = f"%{escaped_q}%"
        exact_q = clean_q.lower()
        limit = max(1, min(limit, 20))

        candidates: list[tuple[str, float]] = []
        seen = set()

        # 1. Track titles
        track_stmt = (
            select(Track.title)
            .where(
                and_(
                    Track.status == "READY",
                    or_(Track.title.ilike(prefix_q), Track.title.ilike(substr_q)),
                )
            )
            .limit(limit * 2)
        )
        track_res = await self.session.execute(track_stmt)
        for (title,) in track_res.all():
            if title and title.strip().lower() not in seen:
                clean_title = title.strip()
                seen.add(clean_title.lower())
                score = 100.0 if clean_title.lower() == exact_q else (50.0 if clean_title.lower().startswith(exact_q) else 25.0)
                candidates.append((clean_title, score))

        # 2. Artist names
        artist_stmt = (
            select(Track.artist_name)
            .where(
                and_(
                    Track.status == "READY",
                    Track.artist_name.isnot(None),
                    or_(Track.artist_name.ilike(prefix_q), Track.artist_name.ilike(substr_q)),
                )
            )
            .distinct()
            .limit(limit * 2)
        )
        artist_res = await self.session.execute(artist_stmt)
        for (artist_name,) in artist_res.all():
            if artist_name and artist_name.strip().lower() not in seen:
                clean_artist = artist_name.strip()
                seen.add(clean_artist.lower())
                score = 95.0 if clean_artist.lower() == exact_q else (48.0 if clean_artist.lower().startswith(exact_q) else 24.0)
                candidates.append((clean_artist, score))

        # 3. Album names
        album_stmt = (
            select(Track.album_name)
            .where(
                and_(
                    Track.status == "READY",
                    Track.album_name.isnot(None),
                    or_(Track.album_name.ilike(prefix_q), Track.album_name.ilike(substr_q)),
                )
            )
            .distinct()
            .limit(limit * 2)
        )
        album_res = await self.session.execute(album_stmt)
        for (album_name,) in album_res.all():
            if album_name and album_name.strip().lower() not in seen:
                clean_album = album_name.strip()
                seen.add(clean_album.lower())
                score = 90.0 if clean_album.lower() == exact_q else (45.0 if clean_album.lower().startswith(exact_q) else 22.0)
                candidates.append((clean_album, score))

        # 4. Playlists
        if current_user_id is not None:
            vis_cond = or_(Playlist.is_public == True, Playlist.owner_id == current_user_id)
        else:
            vis_cond = Playlist.is_public == True

        playlist_stmt = (
            select(Playlist.name)
            .where(
                and_(
                    vis_cond,
                    or_(Playlist.name.ilike(prefix_q), Playlist.name.ilike(substr_q)),
                )
            )
            .limit(limit * 2)
        )
        playlist_res = await self.session.execute(playlist_stmt)
        for (p_name,) in playlist_res.all():
            if p_name and p_name.strip().lower() not in seen:
                clean_pname = p_name.strip()
                seen.add(clean_pname.lower())
                score = 85.0 if clean_pname.lower() == exact_q else (40.0 if clean_pname.lower().startswith(exact_q) else 20.0)
                candidates.append((clean_pname, score))

        # Sort candidates by score descending, then by length ascending (shorter matches first)
        candidates.sort(key=lambda c: (-c[1], len(c[0])))
        return [c[0] for c in candidates[:limit]]
