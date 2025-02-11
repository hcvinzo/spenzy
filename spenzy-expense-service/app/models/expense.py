from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel

class CategoryInfo(BaseModel):
    id: int
    name: str

class TagInfo(BaseModel):
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
    due_date: Optional[datetime] = None
    created_at: datetime
    updated_at: datetime
    tags: List[TagInfo] = []

class ExpenseCreate(BaseModel):
    expense_date: datetime
    vendor_name: str
    total_amount: float
    total_tax: float
    category_id: int
    currency: str
    is_paid: bool
    paid_on: Optional[datetime] = None
    due_date: Optional[datetime] = None
    tag_ids: List[int] = []

class ExpenseUpdate(BaseModel):
    expense_date: Optional[datetime] = None
    vendor_name: Optional[str] = None
    total_amount: Optional[float] = None
    total_tax: Optional[float] = None
    category_id: Optional[int] = None
    currency: Optional[str] = None
    is_paid: Optional[bool] = None
    paid_on: Optional[datetime] = None
    due_date: Optional[datetime] = None
    tag_ids: Optional[List[int]] = None 