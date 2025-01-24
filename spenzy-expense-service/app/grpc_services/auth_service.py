import grpc
from proto import auth_pb2, auth_pb2_grpc
from spenzy_common.auth.auth_service import AuthService as KeycloakAuthService, AuthenticationError

class AuthService(auth_pb2_grpc.AuthServiceServicer):
    def __init__(self):
        self.keycloak_auth = KeycloakAuthService()

    def Authenticate(self, request, context):
        try:
            result = self.keycloak_auth.authenticate(
                username=request.username,
                password=request.password
            )
            return auth_pb2.AuthResponse(
                access_token=result['access_token'],
                refresh_token=result['refresh_token'],
                expires_in=result['expires_in']
            )
        except AuthenticationError as e:
            context.abort(grpc.StatusCode.UNAUTHENTICATED, str(e))
        except Exception as e:
            context.abort(grpc.StatusCode.INTERNAL, f"Authentication failed: {str(e)}")

    def RefreshToken(self, request, context):
        try:
            result = self.keycloak_auth.refresh_token(
                refresh_token=request.refresh_token
            )
            return auth_pb2.AuthResponse(
                access_token=result['access_token'],
                refresh_token=result['refresh_token'],
                expires_in=result['expires_in']
            )
        except AuthenticationError as e:
            context.abort(grpc.StatusCode.UNAUTHENTICATED, str(e))
        except Exception as e:
            context.abort(grpc.StatusCode.INTERNAL, f"Token refresh failed: {str(e)}")

    def ExchangeToken(self, request, context):
        try:
            result = self.keycloak_auth.exchange_token(
                token=request.token
            )
            return auth_pb2.AuthResponse(
                access_token=result['access_token'],
                refresh_token=result['refresh_token'],
                expires_in=result['expires_in']
            )
        except AuthenticationError as e:
            context.abort(grpc.StatusCode.UNAUTHENTICATED, str(e))
        except Exception as e:
            context.abort(grpc.StatusCode.INTERNAL, f"Token exchange failed: {str(e)}") 