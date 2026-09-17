from typing import Any, Generic, List, Optional, Type, TypeVar
import uuid
from sqlalchemy import select, delete, update
from sqlalchemy.ext.asyncio import AsyncSession
from app.db.base import Base

ModelT = TypeVar("ModelT", bound=Base)


class BaseRepository(Generic[ModelT]):
    """Generic repository implementing standard asynchronous CRUD operations."""

    def __init__(self, model: Type[ModelT], session: AsyncSession):
        self.model = model
        self.session = session

    async def get_by_id(self, id: uuid.UUID) -> Optional[ModelT]:
        """Retrieves a single record by primary key UUID."""
        stmt = select(self.model).where(self.model.id == id)
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def list_all(self, skip: int = 0, limit: int = 50) -> List[ModelT]:
        """Retrieves a paginated list of records."""
        stmt = select(self.model).offset(skip).limit(limit)
        result = await self.session.execute(stmt)
        return list(result.scalars().all())

    async def create(self, **kwargs: Any) -> ModelT:
        """Instantiates and persists a new record."""
        instance = self.model(**kwargs)
        self.session.add(instance)
        await self.session.flush()
        await self.session.refresh(instance)
        return instance

    async def delete(self, id: uuid.UUID) -> bool:
        """Deletes a record by UUID."""
        stmt = delete(self.model).where(self.model.id == id)
        result = await self.session.execute(stmt)
        return result.rowcount > 0
