import os
import grpc
import logging
from proto import expense_pb2
from proto import expense_pb2_grpc
from spenzy_common.auth.auth_service import AuthService as KeycloakAuthService

logger = logging.getLogger(__name__)

class CategoryClient:
    def __init__(self):
        self.channel = grpc.aio.insecure_channel('localhost:50052')
        self.stub = expense_pb2_grpc.CategoryServiceStub(self.channel)
        self.auth_service = KeycloakAuthService()
        self._access_token = None

    async def _ensure_token(self):
        """Ensure we have a valid access token using client credentials."""
        try:
            if not self._access_token:
                # Get client credentials from environment
                client_id = os.getenv('EXPENSE_SERVICE_CLIENT_ID')
                client_secret = os.getenv('EXPENSE_SERVICE_CLIENT_SECRET')
                
                if not client_secret:
                    raise ValueError("EXPENSE_SERVICE_CLIENT_SECRET environment variable is not set")
                
                # Get token using client credentials
                result = await self.auth_service.client_credentials_token(
                    client_id=client_id,
                    client_secret=client_secret
                )
                self._access_token = result['access_token']
            
            return self._access_token
        except Exception as e:
            logger.error(f"Failed to get client credentials token: {e}")
            raise

    def _get_metadata(self, token):
        """Create metadata with authorization token."""
        return [('authorization', f'Bearer {token}')]

    async def get_categories(self):
        """Get all categories using client credentials."""
        try:
            token = await self._ensure_token()
            metadata = self._get_metadata(token)
            
            request = expense_pb2.ListCategoriesRequest()
            response = await self.stub.ListCategories(request, metadata=metadata)
            
            if response.success:
                return [cat.name for cat in response.categories]
            else:
                logger.error(f"Failed to get categories: {response.error_message}")
                return self._get_default_categories()
                
        except grpc.RpcError as e:
            logger.error(f"gRPC error in get_categories: {e}")
            if e.code() == grpc.StatusCode.UNAUTHENTICATED:
                # Token might be expired, clear it and retry once
                self._access_token = None
                try:
                    token = await self._ensure_token()
                    metadata = self._get_metadata(token)
                    response = await self.stub.ListCategories(request, metadata=metadata)
                    if response.success:
                        return [cat.name for cat in response.categories]
                except Exception as retry_e:
                    logger.error(f"Retry failed: {retry_e}")
            
            # Return default categories as fallback
            return self._get_default_categories()
            
        except Exception as e:
            logger.error(f"Error in get_categories: {e}")
            return self._get_default_categories()

    def _get_default_categories(self):
        """Return default categories as fallback."""
        return [
            "Groceries", "Restaurants", "Electricity", "Communication",
            "Water", "Gas/Fuel", "Clothing", "Medical/Healthcare",
            "Household Items/Supplies", "Personal", "Education",
            "Entertainment", "Others"
        ]

    async def close(self):
        """Close the gRPC channel."""
        await self.channel.close() 