import grpc
from datetime import datetime
from google.protobuf import timestamp_pb2
from sqlalchemy.orm import Session
from proto import expense_pb2, expense_pb2_grpc
from app.database import get_db, Expense
from spenzy_common.utils.token_utils import get_user_id_from_context

def timestamp_to_datetime(ts):
    """Convert Protobuf Timestamp to Python datetime."""
    return datetime.fromtimestamp(ts.seconds + ts.nanos / 1e9)

def datetime_to_timestamp(dt):
    """Convert Python datetime to Protobuf Timestamp."""
    ts = timestamp_pb2.Timestamp()
    ts.FromDatetime(dt)
    return ts

class ExpenseService(expense_pb2_grpc.ExpenseServiceServicer):
    """
    Service for managing expenses.
    Database implementation will be added later.
    """
    
    def CreateExpense(self, request, context):
        """Create a new expense"""
        try:
            # Get database session
            db = next(get_db())
            
            # Convert timestamp to datetime
            expense_date = timestamp_to_datetime(request.expense_date)
            paid_on = timestamp_to_datetime(request.paid_on) if request.is_paid else None
            
            # Get user ID from token
            user_id = get_user_id_from_context(context)
            
            # Create new expense
            expense = Expense(
                expense_date=expense_date,
                vendor_name=request.vendor_name,
                total_amount=request.total_amount,
                total_tax=request.total_tax,
                category=request.category,
                currency=request.currency,
                is_paid=request.is_paid,
                paid_on=paid_on,
                created_by=user_id,
                updated_by=user_id
            )
            
            db.add(expense)
            db.commit()
            db.refresh(expense)
            
            # Convert to response
            return expense_pb2.ExpenseResponse(
                success=True,
                expense=expense_pb2.Expense(
                    id=expense.id,
                    expense_date=datetime_to_timestamp(expense.expense_date),
                    vendor_name=expense.vendor_name,
                    total_amount=expense.total_amount,
                    total_tax=expense.total_tax,
                    category=expense.category,
                    currency=expense.currency,
                    is_paid=expense.is_paid,
                    paid_on=datetime_to_timestamp(expense.paid_on) if expense.paid_on else None,
                    created_on=datetime_to_timestamp(expense.created_on),
                    created_by=expense.created_by,
                    updated_on=datetime_to_timestamp(expense.updated_on),
                    updated_by=expense.updated_by
                )
            )
        except Exception as e:
            context.abort(grpc.StatusCode.INTERNAL, str(e))

    def GetExpense(self, request, context):
        """Get an expense by ID"""
        try:
            # Get database session
            db = next(get_db())
            
            # Get user ID from token
            user_id = get_user_id_from_context(context)
            
            # Get expense by ID
            expense = db.query(Expense).filter(
                Expense.id == request.id,
                Expense.created_by == user_id
            ).first()
            
            if not expense:
                context.abort(grpc.StatusCode.NOT_FOUND, "Expense not found")
            
            # Convert to response
            return expense_pb2.ExpenseResponse(
                success=True,
                expense=expense_pb2.Expense(
                    id=expense.id,
                    expense_date=datetime_to_timestamp(expense.expense_date),
                    vendor_name=expense.vendor_name,
                    total_amount=expense.total_amount,
                    total_tax=expense.total_tax,
                    category=expense.category,
                    currency=expense.currency,
                    is_paid=expense.is_paid,
                    paid_on=datetime_to_timestamp(expense.paid_on) if expense.paid_on else None,
                    created_on=datetime_to_timestamp(expense.created_on),
                    created_by=expense.created_by,
                    updated_on=datetime_to_timestamp(expense.updated_on),
                    updated_by=expense.updated_by
                )
            )
        except grpc.RpcError:
            raise
        except Exception as e:
            context.abort(grpc.StatusCode.INTERNAL, str(e))

    def UpdateExpense(self, request, context):
        """Update an existing expense"""
        try:
            # Get database session
            db = next(get_db())
            
            # Get user ID from token
            user_id = get_user_id_from_context(context)
            
            # Get expense by ID
            expense = db.query(Expense).filter(
                Expense.id == request.id,
                Expense.created_by == user_id
            ).first()
            
            if not expense:
                context.abort(grpc.StatusCode.NOT_FOUND, "Expense not found")
            
            # Update fields
            expense.expense_date = timestamp_to_datetime(request.expense_date)
            expense.vendor_name = request.vendor_name
            expense.total_amount = request.total_amount
            expense.total_tax = request.total_tax
            expense.category = request.category
            expense.currency = request.currency
            expense.is_paid = request.is_paid
            expense.paid_on = timestamp_to_datetime(request.paid_on) if request.is_paid else None
            expense.updated_by = user_id
            
            db.commit()
            db.refresh(expense)
            
            # Convert to response
            return expense_pb2.ExpenseResponse(
                success=True,
                expense=expense_pb2.Expense(
                    id=expense.id,
                    expense_date=datetime_to_timestamp(expense.expense_date),
                    vendor_name=expense.vendor_name,
                    total_amount=expense.total_amount,
                    total_tax=expense.total_tax,
                    category=expense.category,
                    currency=expense.currency,
                    is_paid=expense.is_paid,
                    paid_on=datetime_to_timestamp(expense.paid_on) if expense.paid_on else None,
                    created_on=datetime_to_timestamp(expense.created_on),
                    created_by=expense.created_by,
                    updated_on=datetime_to_timestamp(expense.updated_on),
                    updated_by=expense.updated_by
                )
            )
        except grpc.RpcError:
            raise
        except Exception as e:
            context.abort(grpc.StatusCode.INTERNAL, str(e))

    def DeleteExpense(self, request, context):
        """Delete an expense"""
        try:
            # Get database session
            db = next(get_db())
            
            # Get user ID from token
            user_id = get_user_id_from_context(context)
            
            # Get expense by ID
            expense = db.query(Expense).filter(
                Expense.id == request.id,
                Expense.created_by == user_id
            ).first()
            
            if not expense:
                context.abort(grpc.StatusCode.NOT_FOUND, "Expense not found")
            
            # Delete expense
            db.delete(expense)
            db.commit()
            
            return expense_pb2.DeleteExpenseResponse(
                success=True
            )
        except grpc.RpcError:
            raise
        except Exception as e:
            context.abort(grpc.StatusCode.INTERNAL, str(e))

    def ListExpenses(self, request, context):
        """List expenses with pagination and filtering"""
        try:
            # Get database session
            db = next(get_db())
            
            # Get user ID from token
            user_id = get_user_id_from_context(context)
            
            # Base query
            query = db.query(Expense).filter(Expense.created_by == user_id)
            
            # Apply filters
            for key, value in request.filters.items():
                if hasattr(Expense, key):
                    query = query.filter(getattr(Expense, key) == value)
            
            # Get total count
            total_count = query.count()
            
            # Apply sorting
            if request.sort_by and hasattr(Expense, request.sort_by):
                order_by = getattr(Expense, request.sort_by)
                if not request.ascending:
                    order_by = order_by.desc()
                query = query.order_by(order_by)
            
            # Apply pagination
            page = max(1, request.page)
            page_size = max(1, min(100, request.page_size))  # Limit page size to 100
            query = query.offset((page - 1) * page_size).limit(page_size)
            
            # Get expenses
            expenses = query.all()
            
            # Convert to response
            return expense_pb2.ListExpensesResponse(
                success=True,
                total_count=total_count,
                expenses=[
                    expense_pb2.Expense(
                        id=expense.id,
                        expense_date=datetime_to_timestamp(expense.expense_date),
                        vendor_name=expense.vendor_name,
                        total_amount=expense.total_amount,
                        total_tax=expense.total_tax,
                        category=expense.category,
                        currency=expense.currency,
                        is_paid=expense.is_paid,
                        paid_on=datetime_to_timestamp(expense.paid_on) if expense.paid_on else None,
                        created_on=datetime_to_timestamp(expense.created_on),
                        created_by=expense.created_by,
                        updated_on=datetime_to_timestamp(expense.updated_on),
                        updated_by=expense.updated_by
                    ) for expense in expenses
                ]
            )
        except Exception as e:
            context.abort(grpc.StatusCode.INTERNAL, str(e)) 