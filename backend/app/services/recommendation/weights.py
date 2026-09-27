from dataclasses import dataclass


@dataclass(frozen=True)
class RecommendationWeights:
    """Configurable scoring weights for deterministic candidate ranking."""
    genre: float = 0.35
    artist: float = 0.25
    popularity: float = 0.20
    freshness: float = 0.20

    def __post_init__(self):
        total = self.genre + self.artist + self.popularity + self.freshness
        if abs(total - 1.0) > 1e-4:
            raise ValueError(f"RecommendationWeights must sum to 1.0 (currently {total})")
