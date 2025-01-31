import grpc
import asyncio
from datetime import datetime
from google.protobuf import timestamp_pb2
from proto import expense_pb2, expense_pb2_grpc
from app.services.expense_service import ExpenseService
from app.services.category_service import CategoryService
from app.models.expense import ExpenseCreate, ExpenseUpdate
from spenzy_common.middleware.auth_interceptor import AuthInterceptor

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
        self.loop = asyncio.get_event_loop()

    def _expense_to_proto(self, expense):
        """Convert expense model to protobuf message."""
        expense_date = timestamp_pb2.Timestamp()
        expense_date.FromDatetime(expense.expense_date)

        paid_on = None
        if expense.paid_on:
            paid_on = timestamp_pb2.Timestamp()
            paid_on.FromDatetime(expense.paid_on)

        created_at = timestamp_pb2.Timestamp()
        created_at.FromDatetime(expense.created_at)

        updated_at = timestamp_pb2.Timestamp()
        updated_at.FromDatetime(expense.updated_at)

        category = None
        if expense.category:
            category = expense_pb2.Category(
                id=expense.category.id,
                name=expense.category.name
            )

        return expense_pb2.Expense(
            id=expense.id,
            expense_date=expense_date,
            vendor_name=expense.vendor_name,
            total_amount=expense.total_amount,
            total_tax=expense.total_tax,
            category_id=expense.category_id,
            category=category,
            currency=expense.currency,
            is_paid=expense.is_paid,
            paid_on=paid_on,
            created_at=created_at,
            updated_at=updated_at
        )

    def CreateExpense(self, request, context):
        """Create a new expense."""
        try:
            # Validate category exists
            category = self.loop.run_until_complete(
                self.category_service.get_category(request.category_id)
            )
            if not category:
                context.set_code(grpc.StatusCode.INVALID_ARGUMENT)
                context.set_details(f"Category with ID {request.category_id} not found")
                return expense_pb2.CreateExpenseResponse()

            expense = ExpenseCreate(
                expense_date=request.expense_date.ToDatetime(),
                vendor_name=request.vendor_name,
                total_amount=request.total_amount,
                total_tax=request.total_tax,
                category_id=request.category_id,
                currency=request.currency,
                is_paid=request.is_paid,
                paid_on=request.paid_on.ToDatetime() if request.is_paid and request.paid_on else None
            )

            result = self.loop.run_until_complete(
                self.expense_service.create_expense(context.user_id, expense)
            )

            return expense_pb2.CreateExpenseResponse(
                expense=self._expense_to_proto(result)
            )

        except Exception as e:
            context.set_code(grpc.StatusCode.INTERNAL)
            context.set_details(str(e))
            return expense_pb2.CreateExpenseResponse()

    def GetExpense(self, request, context):
        """Get an expense by ID."""
        try:
            expense = self.loop.run_until_complete(
                self.expense_service.get_expense(context.user_id, request.expense_id)
            )

            if not expense:
                context.set_code(grpc.StatusCode.NOT_FOUND)
                context.set_details(f"Expense {request.expense_id} not found")
                return expense_pb2.GetExpenseResponse()

            return expense_pb2.GetExpenseResponse(
                expense=self._expense_to_proto(expense)
            )

        except Exception as e:
            context.set_code(grpc.StatusCode.INTERNAL)
            context.set_details(str(e))
            return expense_pb2.GetExpenseResponse()

    def ListExpenses(self, request, context):
        """List expenses with pagination and sorting."""
        try:
            expenses = self.loop.run_until_complete(
                self.expense_service.list_expenses(
                    context.user_id,
                    page=request.page,
                    page_size=request.page_size,
                    sort_by=request.sort_by,
                    ascending=request.ascending
                )
            )

            return expense_pb2.ListExpensesResponse(
                expenses=[self._expense_to_proto(expense) for expense in expenses]
            )

        except Exception as e:
            context.set_code(grpc.StatusCode.INTERNAL)
            context.set_details(str(e))
            return expense_pb2.ListExpensesResponse()

    def UpdateExpense(self, request, context):
        """Update an expense."""
        try:
            # If category_id is provided, validate it exists
            if request.HasField('category_id'):
                category = self.loop.run_until_complete(
                    self.category_service.get_category(request.category_id)
                )
                if not category:
                    context.set_code(grpc.StatusCode.INVALID_ARGUMENT)
                    context.set_details(f"Category with ID {request.category_id} not found")
                    return expense_pb2.UpdateExpenseResponse()

            # Build update data from request
            update_data = {}
            for field, value in request.ListFields():
                if field.name not in ['expense_id']:  # Skip ID field
                    if field.name in ['expense_date', 'paid_on']:
                        update_data[field.name] = value.ToDatetime()
                    else:
                        update_data[field.name] = value

            expense = self.loop.run_until_complete(
                self.expense_service.update_expense(
                    context.user_id,
                    request.expense_id,
                    ExpenseUpdate(**update_data)
                )
            )

            if not expense:
                context.set_code(grpc.StatusCode.NOT_FOUND)
                context.set_details(f"Expense {request.expense_id} not found")
                return expense_pb2.UpdateExpenseResponse()

            return expense_pb2.UpdateExpenseResponse(
                expense=self._expense_to_proto(expense)
            )

        except Exception as e:
            context.set_code(grpc.StatusCode.INTERNAL)
            context.set_details(str(e))
            return expense_pb2.UpdateExpenseResponse()

    def DeleteExpense(self, request, context):
        """Delete an expense."""
        try:
            success = self.loop.run_until_complete(
                self.expense_service.delete_expense(context.user_id, request.expense_id)
            )

            if not success:
                context.set_code(grpc.StatusCode.NOT_FOUND)
                context.set_details(f"Expense {request.expense_id} not found")
                return expense_pb2.DeleteExpenseResponse(success=False)

            return expense_pb2.DeleteExpenseResponse(success=True)

        except Exception as e:
            context.set_code(grpc.StatusCode.INTERNAL)
            context.set_details(str(e))
            return expense_pb2.DeleteExpenseResponse(success=False) 