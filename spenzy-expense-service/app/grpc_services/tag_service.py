import grpc
import logging
from google.protobuf.timestamp_pb2 import Timestamp
from proto import expense_pb2, expense_pb2_grpc
from app.services.tag_service import TagService
from spenzy_common.utils.token_utils import get_user_id_from_context

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class TagServicer(expense_pb2_grpc.TagServiceServicer):
    def __init__(self):
        self.tag_service = TagService()

    def _tag_to_proto(self, tag):
        """Convert tag model to protobuf message."""
        created_at = Timestamp()
        created_at.FromDatetime(tag.created_at)

        updated_at = Timestamp()
        updated_at.FromDatetime(tag.updated_at)

        return expense_pb2.Tag(
            id=tag.id,
            name=tag.name,
            created_at=created_at,
            created_by=tag.created_by,
            updated_at=updated_at,
            updated_by=tag.updated_by
        )

    async def ListTags(self, request, context):
        """List all tags for a user."""
        try:
            user_id = get_user_id_from_context(context)
            tags = await self.tag_service.get_tags(user_id, request.query)
            
            return expense_pb2.ListTagsResponse(
                tags=[self._tag_to_proto(tag) for tag in tags],
                success=True
            )
        except Exception as e:
            error_msg = f"ListTags failed: {str(e)}"
            logger.error(error_msg, exc_info=True)
            return expense_pb2.ListTagsResponse(
                success=False,
                error_message=error_msg
            )

    async def CreateTag(self, request, context):
        """Create a new tag."""
        try:
            user_id = get_user_id_from_context(context)
            tag = await self.tag_service.create_tag(user_id, request.name)
            
            return expense_pb2.TagResponse(
                tag=self._tag_to_proto(tag),
                success=True
            )
        except Exception as e:
            error_msg = f"CreateTag failed: {str(e)}"
            logger.error(error_msg, exc_info=True)
            return expense_pb2.TagResponse(
                success=False,
                error_message=error_msg
            )

    async def DeleteTag(self, request, context):
        """Delete a tag."""
        try:
            user_id = get_user_id_from_context(context)
            success = await self.tag_service.delete_tag(user_id, request.tag_id)
            
            if not success:
                error_msg = f"Tag {request.tag_id} not found"
                logger.error(f"DeleteTag failed: {error_msg}")
                return expense_pb2.DeleteTagResponse(
                    success=False,
                    error_message=error_msg
                )
            
            return expense_pb2.DeleteTagResponse(success=True)
        except Exception as e:
            error_msg = f"DeleteTag failed: {str(e)}"
            logger.error(error_msg, exc_info=True)
            return expense_pb2.DeleteTagResponse(
                success=False,
                error_message=error_msg
            ) 