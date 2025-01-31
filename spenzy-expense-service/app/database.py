import os
from datetime import datetime
from sqlalchemy import create_engine, Column, Integer, String, Float, Boolean, DateTime, ForeignKey, Text
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, relationship

# Create database URL
DATABASE_URL = f"postgresql://spenzy:1234@localhost/spenzy"

# Create SQLAlchemy engine
engine = create_engine(DATABASE_URL)

# Create session factory
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Create declarative base
Base = declarative_base()

# Create Category model
class Category(Base):
    __tablename__ = "categories"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(50), nullable=False, unique=True)
    description = Column(Text)
    
    # Audit fields
    created_at = Column(DateTime(timezone=True), default=datetime.utcnow, nullable=False)
    created_by = Column(String(255), nullable=False)
    updated_at = Column(DateTime(timezone=True), default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)
    updated_by = Column(String(255), nullable=False)

    # Relationships
    expenses = relationship("Expense", back_populates="category")

# Create Expense model
class Expense(Base):
    __tablename__ = "expenses"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(String(255), nullable=False)  # Owner of the expense
    expense_date = Column(DateTime, nullable=False)
    vendor_name = Column(String, nullable=False)
    total_amount = Column(Float, nullable=False)
    total_tax = Column(Float, nullable=False)
    category_id = Column(Integer, ForeignKey("categories.id"), nullable=False)
    currency = Column(String, nullable=False)
    is_paid = Column(Boolean, default=False)
    paid_on = Column(DateTime, nullable=True)
    
    # Audit fields
    created_at = Column(DateTime(timezone=True), default=datetime.utcnow, nullable=False)
    created_by = Column(String(255), nullable=False)  # Who created the record (user/system/agent)
    updated_at = Column(DateTime(timezone=True), default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)
    updated_by = Column(String(255), nullable=False)  # Who last modified the record (user/system/agent)

    # Relationships
    category = relationship("Category", back_populates="expenses")

# Create all tables
def init_db():
    Base.metadata.create_all(bind=engine)

# Get database session
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close() 