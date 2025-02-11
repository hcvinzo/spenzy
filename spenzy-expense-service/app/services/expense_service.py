from typing import List, Optional
from datetime import datetime
import logging
from sqlalchemy import select
from sqlalchemy.orm import joinedload
from app.database import get_db, Expense, Category, Tag
from app.models.expense import ExpenseCreate, ExpenseUpdate

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class ExpenseService:
    async def get_expense(self, user_id: str, expense_id: int) -> Optional[Expense]:
        """Get an expense by ID."""
        async for session in get_db():
            stmt = select(Expense).options(
                joinedload(Expense.category),
                joinedload(Expense.tags)
            ).filter(
                Expense.user_id == user_id,
                Expense.id == expense_id
            )
            result = await session.execute(stmt)
            return result.unique().scalar_one_or_none()

    async def list_expenses(
        self,
        user_id: str,
        page: int = 1,
        page_size: int = 10,
        sort_by: str = 'expense_date',
        ascending: bool = False
    ) -> List[Expense]:
        """List expenses with pagination and sorting."""
        logger.info(f"Listing expenses for user_id: {user_id}, page: {page}, page_size: {page_size}")
        offset = (page - 1) * page_size

        async for session in get_db():
            try:
                stmt = select(Expense).options(
                    joinedload(Expense.category),
                    joinedload(Expense.tags)
                ).filter(
                    Expense.user_id == user_id
                )

                # Apply sorting
                if ascending:
                    stmt = stmt.order_by(getattr(Expense, sort_by).asc())
                else:
                    stmt = stmt.order_by(getattr(Expense, sort_by).desc())

                # Apply pagination
                stmt = stmt.offset(offset).limit(page_size)
                
                logger.info(f"Executing query: {stmt}")
                result = await session.execute(stmt)
                expenses = list(result.unique().scalars().all())
                logger.info(f"Found {len(expenses)} expenses")
                
                return expenses
            except Exception as e:
                logger.error(f"Error listing expenses: {str(e)}", exc_info=True)
                raise

    async def create_expense(self, user_id: str, expense: ExpenseCreate) -> Expense:
        """Create a new expense."""
        db_expense = Expense(
            user_id=user_id,
            expense_date=expense.expense_date,
            vendor_name=expense.vendor_name,
            total_amount=expense.total_amount,
            total_tax=expense.total_tax,
            category_id=expense.category_id,
            currency=expense.currency,
            is_paid=expense.is_paid,
            paid_on=expense.paid_on if expense.is_paid else None,
            due_date=expense.due_date,
            created_by=user_id,
            updated_by=user_id
        )

        async for session in get_db():
            try:
                # Get tags if provided
                if expense.tag_ids:
                    stmt = select(Tag).filter(
                        Tag.id.in_(expense.tag_ids),
                        Tag.user_id == user_id
                    )
                    result = await session.execute(stmt)
                    tags = result.scalars().all()
                    db_expense.tags.extend(tags)  # Use extend to add tags to the relationship

                session.add(db_expense)
                await session.commit()
                await session.refresh(db_expense, ['category', 'tags'])
                return db_expense
            except Exception as e:
                logger.error(f"Error creating expense: {str(e)}", exc_info=True)
                await session.rollback()
                raise

    async def update_expense(self, user_id: str, expense_id: int, expense: ExpenseUpdate) -> Optional[Expense]:
        """Update an expense."""
        async for session in get_db():
            # Get existing expense
            stmt = select(Expense).filter(
                Expense.id == expense_id,
                Expense.user_id == user_id
            )
            result = await session.execute(stmt)
            db_expense = result.scalar_one_or_none()

            if not db_expense:
                return None

            # Update fields
            update_data = expense.model_dump(exclude_unset=True)
            
            # Handle special cases
            if 'is_paid' in update_data:
                if not update_data['is_paid']:
                    update_data['paid_on'] = None
                elif 'paid_on' not in update_data:
                    update_data['paid_on'] = datetime.utcnow()

            # Update tags if provided
            if 'tag_ids' in update_data:
                stmt = select(Tag).filter(
                    Tag.id.in_(update_data['tag_ids']),
                    Tag.user_id == user_id
                )
                result = await session.execute(stmt)
                tags = result.scalars().all()
                db_expense.tags = tags
                del update_data['tag_ids']

            # Always update updated_by
            update_data['updated_by'] = user_id

            # Update fields
            for field, value in update_data.items():
                setattr(db_expense, field, value)

            await session.commit()
            await session.refresh(db_expense, ['category', 'tags'])
            return db_expense

    async def delete_expense(self, user_id: str, expense_id: int) -> bool:
        """Delete an expense."""
        async for session in get_db():
            stmt = select(Expense).filter(
                Expense.id == expense_id,
                Expense.user_id == user_id
            )
            result = await session.execute(stmt)
            db_expense = result.scalar_one_or_none()

            if db_expense:
                await session.delete(db_expense)
                await session.commit()
                return True
            return False 