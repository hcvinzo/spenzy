import os
from datetime import datetime
from sqlalchemy import create_engine, Column, Integer, String, Float, Boolean, DateTime, Enum
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker

# Create database URL
DATABASE_URL = f"postgresql://spenzy:1234@localhost/spenzy"

# Create SQLAlchemy engine
engine = create_engine(DATABASE_URL)

# Create session factory
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Create declarative base
Base = declarative_base()

# Create Expense model
class Expense(Base):
    __tablename__ = "expenses"

    id = Column(Integer, primary_key=True, index=True)
    expense_date = Column(DateTime, nullable=False)
    vendor_name = Column(String, nullable=False)
    total_amount = Column(Float, nullable=False)
    total_tax = Column(Float, nullable=False)
    category = Column(String, nullable=False)
    currency = Column(String, nullable=False)
    is_paid = Column(Boolean, default=False)
    paid_on = Column(DateTime, nullable=True)
    
    # Audit fields
    created_on = Column(DateTime, default=datetime.utcnow, nullable=False)
    created_by = Column(String, nullable=False)
    updated_on = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)
    updated_by = Column(String, nullable=False)

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