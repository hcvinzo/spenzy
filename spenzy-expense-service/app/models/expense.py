from datetime import datetime
from typing import Optional
from pydantic import BaseModel

class CategoryInfo(BaseModel):
    id: int
    name: str

class Expense(BaseModel):
    id: int
    user_id: str
    expense_date: datetime
    vendor_name: str
    total_amount: float
    total_tax: float
    category_id: int
    category: Optional[CategoryInfo] = None
    currency: str
    is_paid: bool
    paid_on: Optional[datetime] = None
    created_at: datetime
    updated_at: datetime

class ExpenseCreate(BaseModel):
    expense_date: datetime
    vendor_name: str
    total_amount: float
    total_tax: float
    category_id: int
    currency: str
    is_paid: bool
    paid_on: Optional[datetime] = None

class ExpenseUpdate(BaseModel):
    expense_date: Optional[datetime] = None
    vendor_name: Optional[str] = None
    total_amount: Optional[float] = None
    total_tax: Optional[float] = None
    category_id: Optional[int] = None
    currency: Optional[str] = None
    is_paid: Optional[bool] = None
    paid_on: Optional[datetime] = None 