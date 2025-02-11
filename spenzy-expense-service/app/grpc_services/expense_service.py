import grpc
import asyncio
import logging
from datetime import datetime
from google.protobuf import timestamp_pb2
from google.protobuf.timestamp_pb2 import Timestamp
from sqlalchemy import select
from sqlalchemy.orm import joinedload
from proto import expense_pb2, expense_pb2_grpc
from app.services.expense_service import ExpenseService
from app.services.category_service import CategoryService
from app.models.expense import ExpenseCreate, ExpenseUpdate
from spenzy_common.middleware.auth_interceptor import AuthInterceptor
from spenzy_common.utils.token_utils import get_user_id_from_context
from app.database import get_db, Expense, Category

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

def timestamp_to_datetime(ts):
    """Convert Protobuf Timestamp to Python datetime."""
    return datetime.fromtimestamp(ts.seconds + ts.nanos / 1e9)

def datetime_to_timestamp(dt):
    """Convert Python datetime to Protobuf Timestamp."""
    ts = timestamp_pb2.Timestamp()
    ts.FromDatetime(dt)
    return ts

class ExpenseServicer(expense_pb2_grpc.ExpenseServiceServicer):
    def __init__(self):
        self.expense_service = ExpenseService()
        self.category_service = CategoryService()

    def _expense_to_proto(self, expense):
        """Convert expense model to protobuf message."""
        if not expense:
            return None

        expense_proto = expense_pb2.Expense(
            id=expense.id,
            user_id=expense.user_id,
            vendor_name=expense.vendor_name,
            total_amount=expense.total_amount,
            total_tax=expense.total_tax,
            category_id=expense.category_id,
            currency=expense.currency,
            is_paid=expense.is_paid
        )

        # Handle timestamps
        expense_date = timestamp_pb2.Timestamp()
        expense_date.FromDatetime(expense.expense_date)
        expense_proto.expense_date.CopyFrom(expense_date)

        if expense.paid_on:
            paid_on = timestamp_pb2.Timestamp()
            paid_on.FromDatetime(expense.paid_on)
            expense_proto.paid_on.CopyFrom(paid_on)

        if expense.due_date:
            due_date = timestamp_pb2.Timestamp()
            due_date.FromDatetime(expense.due_date)
            expense_proto.due_date.CopyFrom(due_date)

        created_at = timestamp_pb2.Timestamp()
        created_at.FromDatetime(expense.created_at)
        expense_proto.created_at.CopyFrom(created_at)

        updated_at = timestamp_pb2.Timestamp()
        updated_at.FromDatetime(expense.updated_at)
        expense_proto.updated_at.CopyFrom(updated_at)

        # Handle category
        if expense.category:
            expense_proto.category.id = expense.category.id
            expense_proto.category.name = expense.category.name

        # Handle tags
        if expense.tags:
            for tag in expense.tags:
                tag_proto = expense_proto.tags.add()
                tag_proto.id = tag.id
                tag_proto.name = tag.name

        return expense_proto

    async def CreateExpense(self, request, context):
        """Create a new expense."""
        try:
            user_id = get_user_id_from_context(context)
            if not user_id:
                error_msg = 'User ID not found in token'
                logger.error(f"CreateExpense failed: {error_msg}")
                context.abort(grpc.StatusCode.UNAUTHENTICATED, error_msg)
                return expense_pb2.ExpenseResponse(success=False, error_message=error_msg)

            # Log request
            logger.info(f"CreateExpense request - user_id: {user_id}, vendor: {request.vendor_name}")

            # Create expense data
            expense_data = ExpenseCreate(
                expense_date=request.expense_date.ToDatetime(),
                vendor_name=request.vendor_name,
                total_amount=request.total_amount,
                total_tax=request.total_tax,
                category_id=request.category_id,
                currency=request.currency,
                is_paid=request.is_paid,
                paid_on=request.paid_on.ToDatetime() if request.HasField('paid_on') else None,
                due_date=request.due_date.ToDatetime() if request.HasField('due_date') else None,
                tag_ids=list(request.tag_ids)  # Convert tag_ids from the request to a list
            )

            # Create expense
            expense = await self.expense_service.create_expense(user_id, expense_data)
            if not expense:
                error_msg = "Failed to create expense"
                logger.error(f"CreateExpense failed: {error_msg}")
                return expense_pb2.ExpenseResponse(success=False, error_message=error_msg)

            # Convert to proto and return
            expense_proto = self._expense_to_proto(expense)
            return expense_pb2.ExpenseResponse(
                expense=expense_proto,
                success=True
            )

        except Exception as e:
            error_msg = f"CreateExpense failed: {str(e)}"
            logger.error(error_msg, exc_info=True)
            return expense_pb2.ExpenseResponse(success=False, error_message=error_msg)

    async def GetExpense(self, request, context):
        """Get an expense by ID."""
        try:
            user_id = get_user_id_from_context(context)
            if not user_id:
                error_msg = 'User ID not found in token'
                logger.error(f"GetExpense failed: {error_msg}")
                context.abort(grpc.StatusCode.UNAUTHENTICATED, error_msg)
                return expense_pb2.ExpenseResponse(success=False, error_message=error_msg)

            expense = await self.expense_service.get_expense(user_id, request.id)
            if not expense:
                error_msg = f"Expense {request.id} not found"
                logger.error(f"GetExpense failed: {error_msg}")
                return expense_pb2.ExpenseResponse(success=False, error_message=error_msg)

            expense_proto = self._expense_to_proto(expense)
            return expense_pb2.ExpenseResponse(
                expense=expense_proto,
                success=True
            )

        except Exception as e:
            error_msg = f"GetExpense failed: {str(e)}"
            logger.error(error_msg, exc_info=True)
            return expense_pb2.ExpenseResponse(success=False, error_message=error_msg)

    async def ListExpenses(self, request, context):
        """List expenses with pagination and sorting."""
        try:
            user_id = get_user_id_from_context(context)
            if not user_id:
                error_msg = 'User ID not found in token'
                logger.error(f"ListExpenses failed: {error_msg}")
                context.abort(grpc.StatusCode.UNAUTHENTICATED, error_msg)
                return expense_pb2.ListExpensesResponse(success=False, error_message=error_msg)

            # Get expenses
            expenses = await self.expense_service.list_expenses(
                user_id=user_id,
                page=request.page,
                page_size=request.page_size,
                sort_by=request.sort_by if request.sort_by else 'expense_date',
                ascending=request.ascending
            )

            # Convert to proto messages
            expense_protos = [self._expense_to_proto(expense) for expense in expenses if expense]
            return expense_pb2.ListExpensesResponse(
                expenses=expense_protos,
                success=True
            )

        except Exception as e:
            error_msg = f"ListExpenses failed: {str(e)}"
            logger.error(error_msg, exc_info=True)
            return expense_pb2.ListExpensesResponse(success=False, error_message=error_msg)

    async def UpdateExpense(self, request, context):
        """Update an expense."""
        try:
            user_id = get_user_id_from_context(context)
            if not user_id:
                error_msg = 'User ID not found in token'
                logger.error(f"UpdateExpense failed: {error_msg}")
                context.abort(grpc.StatusCode.UNAUTHENTICATED, error_msg)
                return expense_pb2.ExpenseResponse(success=False, error_message=error_msg)

            # Create update data with only changed fields
            update_data = ExpenseUpdate()

            if request.HasField('expense_date'):
                update_data.expense_date = request.expense_date.ToDatetime()

            if request.HasField('vendor_name'):
                update_data.vendor_name = request.vendor_name

            if request.HasField('total_amount'):
                update_data.total_amount = request.total_amount

            if request.HasField('total_tax'):
                update_data.total_tax = request.total_tax

            if request.HasField('category_id'):
                update_data.category_id = request.category_id

            if request.HasField('currency'):
                update_data.currency = request.currency

            if request.HasField('is_paid'):
                update_data.is_paid = request.is_paid

            if request.HasField('paid_on'):
                update_data.paid_on = request.paid_on.ToDatetime()

            if request.HasField('due_date'):
                update_data.due_date = request.due_date.ToDatetime()

            # Update expense
            expense = await self.expense_service.update_expense(user_id, request.id, update_data)
            if not expense:
                error_msg = f"Expense {request.id} not found"
                logger.error(f"UpdateExpense failed: {error_msg}")
                return expense_pb2.ExpenseResponse(success=False, error_message=error_msg)

            # Convert to proto and return
            expense_proto = self._expense_to_proto(expense)
            return expense_pb2.ExpenseResponse(
                expense=expense_proto,
                success=True
            )

        except Exception as e:
            error_msg = f"UpdateExpense failed: {str(e)}"
            logger.error(error_msg, exc_info=True)
            return expense_pb2.ExpenseResponse(success=False, error_message=error_msg)

    async def DeleteExpense(self, request, context):
        """Delete an expense."""
        try:
            user_id = get_user_id_from_context(context)
            success = await self.expense_service.delete_expense(user_id, request.id)
            
            if not success:
                error_msg = f"Expense {request.id} not found"
                logger.error(f"DeleteExpense failed: {error_msg}")
                return expense_pb2.DeleteExpenseResponse(success=False, error_message=error_msg)
            
            return expense_pb2.DeleteExpenseResponse(success=True)
            
        except Exception as e:
            error_msg = f"DeleteExpense failed: {str(e)}"
            logger.error(error_msg, exc_info=True)
            return expense_pb2.DeleteExpenseResponse(success=False, error_message=error_msg) 