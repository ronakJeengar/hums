import uuid
from datetime import datetime, timezone
from typing import List, Optional
from sqlalchemy import delete, desc, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload
from app.db.models.recommendation import RecommendationItem, RecommendationSet
from app.repositories.base import BaseRepository


class RecommendationSetRepository(BaseRepository[RecommendationSet]):
    """Repository managing RecommendationSet persistence and queries."""

    def __init__(self, session: AsyncSession):
        super().__init__(RecommendationSet, session)

    async def get_latest_active_by_user(
        self, user_id: uuid.UUID
    ) -> Optional[RecommendationSet]:
        """
        Retrieves the latest unexpired recommendation set for a user
        with items and associated tracks eagerly preloaded.
        """
        now = datetime.now(timezone.utc)
        stmt = (
            select(RecommendationSet)
            .options(
                selectinload(RecommendationSet.items).selectinload(
                    RecommendationItem.track
                )
            )
            .where(
                RecommendationSet.user_id == user_id,
                (RecommendationSet.expires_at.is_(None))
                | (RecommendationSet.expires_at > now),
            )
            .order_by(desc(RecommendationSet.created_at))
            .limit(1)
        )
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_id_with_items(
        self, set_id: uuid.UUID
    ) -> Optional[RecommendationSet]:
        """Retrieves a recommendation set by ID with items and tracks preloaded."""
        stmt = (
            select(RecommendationSet)
            .options(
                selectinload(RecommendationSet.items).selectinload(
                    RecommendationItem.track
                )
            )
            .where(RecommendationSet.id == set_id)
        )
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def delete_user_sets(self, user_id: uuid.UUID) -> int:
        """Deletes all existing recommendation sets for a user."""
        stmt = delete(RecommendationSet).where(RecommendationSet.user_id == user_id)
        result = await self.session.execute(stmt)
        await self.session.flush()
        return result.rowcount


class RecommendationItemRepository(BaseRepository[RecommendationItem]):
    """Repository managing RecommendationItem persistence."""

    def __init__(self, session: AsyncSession):
        super().__init__(RecommendationItem, session)

    async def create_items(
        self, items_data: List[dict]
    ) -> List[RecommendationItem]:
        """Bulk creates recommendation items within the active transaction."""
        created_items: List[RecommendationItem] = []
        for data in items_data:
            item = RecommendationItem(
                id=data.get("id", uuid.uuid4()),
                recommendation_set_id=data["recommendation_set_id"],
                track_id=data["track_id"],
                section=data["section"],
                position=data["position"],
                score=data.get("score"),
            )
            self.session.add(item)
            created_items.append(item)
        await self.session.flush()
        return created_items
