from collections import defaultdict
from typing import List, Tuple
from app.db.models.audio import Track


class DiversityService:
    """Enforces diversity rules to prevent artist and genre monopolization."""

    def __init__(
        self,
        max_tracks_per_artist: int = 2,
        max_tracks_per_genre: int = 4,
    ):
        self.max_tracks_per_artist = max_tracks_per_artist
        self.max_tracks_per_genre = max_tracks_per_genre

    def apply_diversity(
        self,
        ranked_candidates: List[Tuple[Track, float]],
        limit: int = 10,
    ) -> List[Tuple[Track, float]]:
        """
        Filters and selects up to `limit` diverse tracks while respecting
        per-artist and per-genre caps.
        """
        selected: List[Tuple[Track, float]] = []
        artist_counts = defaultdict(int)
        genre_counts = defaultdict(int)
        overflow: List[Tuple[Track, float]] = []

        for track, score in ranked_candidates:
            artist = (track.artist_name or "Unknown").strip().lower()
            genre = (track.genre or "Other").strip().lower()

            can_add_artist = artist_counts[artist] < self.max_tracks_per_artist
            can_add_genre = genre_counts[genre] < self.max_tracks_per_genre

            if can_add_artist and can_add_genre:
                selected.append((track, score))
                artist_counts[artist] += 1
                genre_counts[genre] += 1
            else:
                overflow.append((track, score))

            if len(selected) >= limit:
                break

        # If strict diversity left the list short of `limit`, fill with remaining top candidates
        if len(selected) < limit and overflow:
            for item in overflow:
                selected.append(item)
                if len(selected) >= limit:
                    break

        return selected
