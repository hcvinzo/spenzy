import grpc
from google.protobuf.timestamp_pb2 import Timestamp
from proto import expense_pb2, expense_pb2_grpc
from app.services.category_service import CategoryService
from app.models.category import CategoryCreate, CategoryUpdate

class CategoryServicer(expense_pb2_grpc.CategoryServiceServicer):
    def __init__(self):
        self.category_service = CategoryService()

    def _category_to_proto(self, category):
        """Convert category model to protobuf message."""
        created_at = Timestamp()
        created_at.FromDatetime(category.created_at)

        updated_at = Timestamp()
        updated_at.FromDatetime(category.updated_at)

        return expense_pb2.Category(
            id=category.id,
            name=category.name,
            description=category.description or "",
            created_at=created_at,
            updated_at=updated_at,
            created_by=category.created_by,
            updated_by=category.updated_by
        )

    async def ListCategories(self, request, context):
        """List all available expense categories."""
        try:
            categories = await self.category_service.get_categories()
            return expense_pb2.ListCategoriesResponse(
                categories=[self._category_to_proto(cat) for cat in categories],
                success=True
            )
        except Exception as e:
            context.set_code(grpc.StatusCode.INTERNAL)
            context.set_details(str(e))
            return expense_pb2.ListCategoriesResponse(
                success=False,
                error_message=str(e)
            )

    async def GetCategory(self, request, context):
        """Get a category by ID."""
        try:
            category = await self.category_service.get_category(request.category_id)
            if not category:
                context.set_code(grpc.StatusCode.NOT_FOUND)
                context.set_details(f"Category {request.category_id} not found")
                return expense_pb2.GetCategoryResponse()

            return expense_pb2.GetCategoryResponse(
                category=self._category_to_proto(category)
            )
        except Exception as e:
            context.set_code(grpc.StatusCode.INTERNAL)
            context.set_details(str(e))
            return expense_pb2.GetCategoryResponse()

    async def CreateCategory(self, request, context):
        """Create a new category."""
        try:
            category = CategoryCreate(
                name=request.name,
                description=request.description,
                created_by=context.user_id,
                updated_by=context.user_id
            )

            result = await self.category_service.create_category(category)
            return expense_pb2.CreateCategoryResponse(
                category=self._category_to_proto(result)
            )
        except Exception as e:
            context.set_code(grpc.StatusCode.INTERNAL)
            context.set_details(str(e))
            return expense_pb2.CreateCategoryResponse()

    async def UpdateCategory(self, request, context):
        """Update a category."""
        try:
            update_data = CategoryUpdate(
                name=request.name if request.HasField('name') else None,
                description=request.description if request.HasField('description') else None,
                updated_by=context.user_id
            )

            category = await self.category_service.update_category(request.category_id, update_data)

            if not category:
                context.set_code(grpc.StatusCode.NOT_FOUND)
                context.set_details(f"Category {request.category_id} not found")
                return expense_pb2.UpdateCategoryResponse()

            return expense_pb2.UpdateCategoryResponse(
                category=self._category_to_proto(category)
            )
        except Exception as e:
            context.set_code(grpc.StatusCode.INTERNAL)
            context.set_details(str(e))
            return expense_pb2.UpdateCategoryResponse()

    async def DeleteCategory(self, request, context):
        """Delete a category."""
        try:
            success = await self.category_service.delete_category(request.category_id)
            if not success:
                context.set_code(grpc.StatusCode.FAILED_PRECONDITION)
                context.set_details(f"Category {request.category_id} is in use and cannot be deleted")
                return expense_pb2.DeleteCategoryResponse(success=False)

            return expense_pb2.DeleteCategoryResponse(success=True)
        except Exception as e:
            context.set_code(grpc.StatusCode.INTERNAL)
            context.set_details(str(e))
            return expense_pb2.DeleteCategoryResponse(success=False) 