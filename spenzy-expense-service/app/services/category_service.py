from typing import List, Optional
from datetime import datetime
from sqlalchemy import text
from app.database import get_db, Category
from app.models.category import CategoryCreate, CategoryUpdate

class CategoryService:
    def __init__(self):
        self.db = next(get_db())

    async def get_categories(self) -> List[Category]:
        """Get all categories."""
        result = self.db.query(Category).order_by(Category.name).all()
        return result

    async def get_category(self, category_id: int) -> Optional[Category]:
        """Get a category by ID."""
        return self.db.query(Category).filter(Category.id == category_id).first()

    async def create_category(self, category: CategoryCreate) -> Category:
        """Create a new category."""
        db_category = Category(
            name=category.name,
            description=category.description,
            created_by=category.created_by,
            updated_by=category.updated_by
        )
        self.db.add(db_category)
        self.db.commit()
        self.db.refresh(db_category)
        return db_category

    async def update_category(self, category_id: int, category: CategoryUpdate) -> Optional[Category]:
        """Update a category."""
        db_category = await self.get_category(category_id)
        if not db_category:
            return None

        update_data = category.dict(exclude_unset=True)
        for field, value in update_data.items():
            setattr(db_category, field, value)

        self.db.commit()
        self.db.refresh(db_category)
        return db_category

    async def delete_category(self, category_id: int) -> bool:
        """Delete a category if it's not being used by any expenses."""
        # First check if category is being used
        in_use = self.db.execute(
            text("SELECT EXISTS(SELECT 1 FROM expenses WHERE category_id = :category_id)"),
            {"category_id": category_id}
        ).scalar()
        
        if in_use:
            return False

        # If not in use, delete it
        db_category = await self.get_category(category_id)
        if db_category:
            self.db.delete(db_category)
            self.db.commit()
            return True
        return False

    async def get_category_by_name(self, name: str) -> Optional[Category]:
        """Get a category by name."""
        return self.db.query(Category).filter(Category.name == name).first() 