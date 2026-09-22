from datetime import datetime, timezone
from typing import List, Tuple
from app.db.models.audio import Track
from app.services.recommendation.user_preference_service import UserPreferences
from app.services.recommendation.weights import RecommendationWeights


class RankingService:
    """Computes deterministic relevance scores for candidate tracks."""

    def __init__(self, weights: RecommendationWeights = RecommendationWeights()):
        self.weights = weights

    def score_track(
        self, track: Track, preferences: UserPreferences, now: datetime
    ) -> float:
        """Calculates a multi-signal normalized score [0.0, 1.0] for a track."""
        # 1. Genre score
        genre_score = 0.1
        if track.genre and preferences.preferred_genres:
            track_genre_lower = track.genre.strip().lower()
            lower_preferred = [g.lower() for g in preferences.preferred_genres]
            if lower_preferred and track_genre_lower == lower_preferred[0]:
                genre_score = 1.0
            elif track_genre_lower in lower_preferred[:3]:
                genre_score = 0.7
            elif track_genre_lower in lower_preferred:
                genre_score = 0.4

        # 2. Artist score
        artist_score = 0.1
        if track.artist_name and preferences.preferred_artists:
            track_artist_lower = track.artist_name.strip().lower()
            lower_artists = [a.lower() for a in preferences.preferred_artists]
            if track_artist_lower in lower_artists:
                artist_score = 1.0

        # 3. Popularity baseline score (tracks with duration and metadata are given higher quality weight)
        popularity_score = 0.5
        if track.duration_seconds and track.waveform_key:
            popularity_score = 0.8

        # 4. Freshness score (exponential decay over 30 days)
        freshness_score = 0.2
        if track.created_at:
            created = track.created_at
            if created.tzinfo is None:
                created = created.replace(tzinfo=timezone.utc)
            days_old = max(0.0, (now - created).total_seconds() / 86400.0)
            freshness_score = max(0.1, 1.0 - (days_old / 30.0))

        score = (
            (genre_score * self.weights.genre)
            + (artist_score * self.weights.artist)
            + (popularity_score * self.weights.popularity)
            + (freshness_score * self.weights.freshness)
        )
        return round(score, 4)

    def rank_candidates(
        self,
        candidates: List[Track],
        preferences: UserPreferences,
    ) -> List[Tuple[Track, float]]:
        """Ranks candidate tracks descending by their composite recommendation score."""
        now = datetime.now(timezone.utc)
        scored_tracks = [
            (track, self.score_track(track, preferences, now))
            for track in candidates
        ]
        # Sort descending by score, breaking ties by creation date
        scored_tracks.sort(
            key=lambda x: (x[1], x[0].created_at or datetime.min.replace(tzinfo=timezone.utc)),
            reverse=True,
        )
        return scored_tracks
