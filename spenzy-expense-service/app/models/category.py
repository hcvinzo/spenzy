from datetime import datetime
from pydantic import BaseModel

class Category(BaseModel):
    id: int
    name: str
    description: str | None = None
    created_at: datetime
    updated_at: datetime
    created_by: str
    updated_by: str

class CategoryCreate(BaseModel):
    name: str
    description: str | None = None
    created_by: str
    updated_by: str

class CategoryUpdate(BaseModel):
    name: str | None = None
    description: str | None = None
    updated_by: str 