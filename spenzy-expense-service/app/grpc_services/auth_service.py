import grpc
import logging
from proto import auth_pb2, auth_pb2_grpc
from spenzy_common.auth.auth_service import AuthService as KeycloakAuthService, AuthenticationError

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class AuthService(auth_pb2_grpc.AuthServiceServicer):
    def __init__(self):
        self.keycloak_auth = KeycloakAuthService()

    async def Authenticate(self, request, context):
        """Authenticate user with username and password."""
        try:
            result = self.keycloak_auth.authenticate(
                username=request.username,
                password=request.password
            )
            return auth_pb2.AuthResponse(
                access_token=result['access_token'],
                refresh_token=result['refresh_token'],
                expires_in=result['expires_in'],
                success=True
            )
        except AuthenticationError as e:
            error_msg = str(e)
            logger.error(f"Authentication failed: {error_msg}")
            return auth_pb2.AuthResponse(
                access_token="",
                refresh_token="",
                expires_in=0,
                success=False,
                error_message=error_msg
            )
        except Exception as e:
            error_msg = f"Authentication failed: {str(e)}"
            logger.error(error_msg, exc_info=True)
            return auth_pb2.AuthResponse(
                access_token="",
                refresh_token="",
                expires_in=0,
                success=False,
                error_message=error_msg
            )

    async def RefreshToken(self, request, context):
        """Refresh an access token using a refresh token."""
        try:
            result = await self.keycloak_auth.refresh_token(
                refresh_token=request.refresh_token
            )
            return auth_pb2.AuthResponse(
                access_token=result['access_token'],
                refresh_token=result['refresh_token'],
                expires_in=result['expires_in'],
                success=True
            )
        except AuthenticationError as e:
            error_msg = str(e)
            logger.error(f"Token refresh failed: {error_msg}")
            return auth_pb2.AuthResponse(
                access_token="",
                refresh_token="",
                expires_in=0,
                success=False,
                error_message=error_msg
            )
        except Exception as e:
            error_msg = f"Token refresh failed: {str(e)}"
            logger.error(error_msg, exc_info=True)
            return auth_pb2.AuthResponse(
                access_token="",
                refresh_token="",
                expires_in=0,
                success=False,
                error_message=error_msg
            )

    async def ExchangeToken(self, request, context):
        """Exchange a token for a service-specific token."""
        try:
            result = await self.keycloak_auth.exchange_token(
                token=request.token
            )
            return auth_pb2.AuthResponse(
                access_token=result['access_token'],
                refresh_token=result['refresh_token'],
                expires_in=result['expires_in'],
                success=True
            )
        except AuthenticationError as e:
            error_msg = str(e)
            logger.error(f"Token exchange failed: {error_msg}")
            return auth_pb2.AuthResponse(
                access_token="",
                refresh_token="",
                expires_in=0,
                success=False,
                error_message=error_msg
            )
        except Exception as e:
            error_msg = f"Token exchange failed: {str(e)}"
            logger.error(error_msg, exc_info=True)
            return auth_pb2.AuthResponse(
                access_token="",
                refresh_token="",
                expires_in=0,
                success=False,
                error_message=error_msg
            ) 