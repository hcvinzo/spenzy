from typing import List, Optional
from sqlalchemy import select
from sqlalchemy.orm import joinedload
from ..database import get_db, Category
from ..models.category import CategoryCreate, CategoryUpdate

class CategoryService:
    async def get_categories(self) -> List[Category]:
        """Get all categories."""
        async for session in get_db():
            stmt = select(Category).order_by(Category.name)
            result = await session.execute(stmt)
            return list(result.scalars().all())

    async def get_category(self, category_id: int) -> Optional[Category]:
        """Get a category by ID."""
        async for session in get_db():
            stmt = select(Category).filter(Category.id == category_id)
            result = await session.execute(stmt)
            return result.scalar_one_or_none()

    async def create_category(self, category: CategoryCreate) -> Category:
        """Create a new category."""
        db_category = Category(
            name=category.name,
            description=category.description,
            created_by=category.created_by,
            updated_by=category.updated_by
        )
        
        async for session in get_db():
            session.add(db_category)
            await session.commit()
            await session.refresh(db_category)
            return db_category

    async def update_category(self, category_id: int, category: CategoryUpdate) -> Optional[Category]:
        """Update a category."""
        async for session in get_db():
            # Get existing category
            stmt = select(Category).filter(Category.id == category_id)
            result = await session.execute(stmt)
            db_category = result.scalar_one_or_none()
            
            if not db_category:
                return None

            # Update fields
            update_data = category.dict(exclude_unset=True)
            for field, value in update_data.items():
                setattr(db_category, field, value)

            await session.commit()
            await session.refresh(db_category)
            return db_category

    async def delete_category(self, category_id: int) -> bool:
        """Delete a category if it's not being used by any expenses."""
        async for session in get_db():
            # First check if category is being used
            stmt = select(Category).filter(Category.id == category_id)
            result = await session.execute(stmt)
            db_category = result.scalar_one_or_none()
            
            if not db_category:
                return False

            # Check if category has any expenses
            if db_category.expenses:
                return False

            # If not in use, delete it
            await session.delete(db_category)
            await session.commit()
            return True

    async def get_category_by_name(self, name: str) -> Optional[Category]:
        """Get a category by name."""
        async for session in get_db():
            stmt = select(Category).filter(Category.name == name)
            result = await session.execute(stmt)
            return result.scalar_one_or_none() 