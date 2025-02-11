from typing import List, Optional
from sqlalchemy import select
from app.database import get_db, Tag

class TagService:
    async def get_tags(self, user_id: str, query: Optional[str] = None) -> List[Tag]:
        """Get all tags for a user, optionally filtered by query."""
        async for session in get_db():
            stmt = select(Tag).filter(Tag.user_id == user_id)
            
            if query:
                stmt = stmt.filter(Tag.name.ilike(f"%{query}%"))
                
            stmt = stmt.order_by(Tag.name)
            result = await session.execute(stmt)
            return list(result.scalars().all())

    async def create_tag(self, user_id: str, name: str) -> Tag:
        """Create a new tag."""
        async for session in get_db():
            # Check if tag already exists for this user
            stmt = select(Tag).filter(
                Tag.user_id == user_id,
                Tag.name == name
            )
            result = await session.execute(stmt)
            existing_tag = result.scalar_one_or_none()
            
            if existing_tag:
                return existing_tag
            
            # Create new tag
            tag = Tag(
                name=name,
                user_id=user_id,
                created_by=user_id,
                updated_by=user_id
            )
            
            session.add(tag)
            await session.commit()
            await session.refresh(tag)
            return tag

    async def delete_tag(self, user_id: str, tag_id: int) -> bool:
        """Delete a tag."""
        async for session in get_db():
            stmt = select(Tag).filter(
                Tag.id == tag_id,
                Tag.user_id == user_id
            )
            result = await session.execute(stmt)
            tag = result.scalar_one_or_none()
            
            if not tag:
                return False
            
            await session.delete(tag)
            await session.commit()
            return True

    async def get_or_create_tags(self, user_id: str, tag_names: List[str]) -> List[Tag]:
        """Get or create multiple tags by name."""
        tags = []
        async for session in get_db():
            for name in tag_names:
                # Try to find existing tag
                stmt = select(Tag).filter(
                    Tag.user_id == user_id,
                    Tag.name == name
                )
                result = await session.execute(stmt)
                tag = result.scalar_one_or_none()
                
                if not tag:
                    # Create new tag
                    tag = Tag(
                        name=name,
                        user_id=user_id,
                        created_by=user_id,
                        updated_by=user_id
                    )
                    session.add(tag)
                
                tags.append(tag)
            
            await session.commit()
            for tag in tags:
                await session.refresh(tag)
            
            return tags 