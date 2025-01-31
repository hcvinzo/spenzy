from typing import List, Optional
from datetime import datetime
from sqlalchemy import text
from app.database import get_db, Expense, Category
from app.models.expense import ExpenseCreate, ExpenseUpdate

class ExpenseService:
    def __init__(self):
        self.db = next(get_db())

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
            created_by=user_id,
            updated_by=user_id
        )
        self.db.add(db_expense)
        self.db.commit()
        self.db.refresh(db_expense)
        
        # Fetch the expense with category information
        return await self.get_expense(user_id, db_expense.id)

    async def get_expense(self, user_id: str, expense_id: int) -> Optional[Expense]:
        """Get an expense by ID."""
        expense = self.db.query(Expense).join(
            Category, Expense.category_id == Category.id, isouter=True
        ).filter(
            Expense.user_id == user_id,
            Expense.id == expense_id
        ).first()

        # Load category relationship if it exists
        if expense and expense.category:
            expense.category_name = expense.category.name

        return expense

    async def list_expenses(
        self,
        user_id: str,
        page: int = 1,
        page_size: int = 10,
        sort_by: str = 'expense_date',
        ascending: bool = False
    ) -> List[Expense]:
        """List expenses with pagination and sorting."""
        # Validate sort_by field
        valid_sort_fields = {'expense_date', 'total_amount', 'vendor_name', 'created_at'}
        if sort_by not in valid_sort_fields:
            sort_by = 'expense_date'

        # Calculate offset
        offset = (page - 1) * page_size

        # Build query
        query = self.db.query(Expense).join(
            Category, Expense.category_id == Category.id, isouter=True
        ).filter(
            Expense.user_id == user_id
        )

        # Apply sorting
        if ascending:
            query = query.order_by(getattr(Expense, sort_by).asc())
        else:
            query = query.order_by(getattr(Expense, sort_by).desc())

        # Apply pagination
        expenses = query.offset(offset).limit(page_size).all()

        # Load category names
        for expense in expenses:
            if expense.category:
                expense.category_name = expense.category.name

        return expenses

    async def update_expense(self, user_id: str, expense_id: int, expense: ExpenseUpdate) -> Optional[Expense]:
        """Update an expense."""
        db_expense = await self.get_expense(user_id, expense_id)
        if not db_expense:
            return None

        update_data = expense.dict(exclude_unset=True)
        
        # Handle special cases
        if 'is_paid' in update_data:
            if not update_data['is_paid']:
                update_data['paid_on'] = None
            elif 'paid_on' not in update_data:
                update_data['paid_on'] = datetime.utcnow()

        # Always update updated_by
        update_data['updated_by'] = user_id

        # Update fields
        for field, value in update_data.items():
            setattr(db_expense, field, value)

        self.db.commit()
        self.db.refresh(db_expense)
        
        # Fetch the updated expense with category information
        return await self.get_expense(user_id, expense_id)

    async def delete_expense(self, user_id: str, expense_id: int) -> bool:
        """Delete an expense."""
        db_expense = await self.get_expense(user_id, expense_id)
        if db_expense:
            self.db.delete(db_expense)
            self.db.commit()
            return True
        return False 