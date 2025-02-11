from .keycloak_handler import KeycloakHandler

class AuthService:
    def __init__(self):
        self.keycloak_handler = KeycloakHandler()

    def authenticate(self, username: str, password: str) -> dict:
        """Authenticate user with Keycloak using username and password."""
        try:
            token_info = self.keycloak_handler.keycloak_openid.token(
                username=username,
                password=password
            )
            return {
                'access_token': token_info.get('access_token', ''),
                'refresh_token': token_info.get('refresh_token', ''),
                'expires_in': token_info.get('expires_in', 0)
            }
        except Exception as e:
            raise AuthenticationError(str(e))

    async def client_credentials_token(self, client_id: str, client_secret: str) -> dict:
        """Get token using client credentials flow."""
        try:
            token_info = await self.keycloak_handler.get_client_credentials_token(
                client_id=client_id,
                client_secret=client_secret
            )
            return {
                'access_token': token_info.get('access_token', ''),
                'refresh_token': token_info.get('refresh_token', ''),
                'expires_in': token_info.get('expires_in', 0)
            }
        except Exception as e:
            raise AuthenticationError(str(e))

    async def refresh_token(self, refresh_token: str) -> dict:
        """Refresh an access token using a refresh token."""
        try:
            token_info = await self.keycloak_handler.verify_token(refresh_token)
            return {
                'access_token': token_info.get('access_token', ''),
                'refresh_token': token_info.get('refresh_token', ''),
                'expires_in': token_info.get('expires_in', 0)
            }
        except Exception as e:
            raise AuthenticationError(str(e))

    async def exchange_token(self, token: str) -> dict:
        """Exchange a token for a service-specific token."""
        try:
            token_info = await self.keycloak_handler.exchange_token(token)
            return {
                'access_token': token_info.get('access_token', ''),
                'refresh_token': token_info.get('refresh_token', ''),
                'expires_in': token_info.get('expires_in', 0)
            }
        except Exception as e:
            raise AuthenticationError(str(e))

class AuthenticationError(Exception):
    """Custom exception for authentication errors."""
    pass 