import os
import httpx
from keycloak import KeycloakOpenID
from keycloak.exceptions import KeycloakError

class KeycloakHandler:
    def __init__(self):
        self.keycloak_openid = KeycloakOpenID(
            server_url=os.getenv('KEYCLOAK_URL'),
            client_id=os.getenv('KEYCLOAK_CLIENT_ID'),
            realm_name=os.getenv('KEYCLOAK_REALM'),
            client_secret_key=os.getenv('KEYCLOAK_CLIENT_SECRET'),
            verify=os.getenv('KEYCLOAK_VERIFY_SSL', 'false').lower() == 'true'
        )
        self._public_key = None

    @property
    def public_key(self):
        if not self._public_key:
            self._public_key = "-----BEGIN PUBLIC KEY-----\n" + \
                self.keycloak_openid.public_key() + \
                "\n-----END PUBLIC KEY-----"
        return self._public_key

    async def get_client_credentials_token(self, client_id: str, client_secret: str) -> dict:
        """Get token using client credentials flow."""
        try:
            params = {
                'grant_type': 'client_credentials',
                'client_id': client_id,
                'client_secret': client_secret
            }
            
            url = f"{os.getenv('KEYCLOAK_URL')}/realms/{os.getenv('KEYCLOAK_REALM')}/protocol/openid-connect/token"
            async with httpx.AsyncClient() as client:
                response = await client.post(url, data=params)
                result = response.json()
                
            if 'error' in result:
                raise KeycloakError(f"Client credentials token failed: {result.get('error_description', result['error'])}")
                
            return result
        except Exception as e:
            raise ValueError(f"Client credentials token failed: {str(e)}")

    async def verify_token(self, token: str):
        """Verify token and return claims"""
        try:
            # Token decoding is CPU-bound, no need for async
            token_info = self.keycloak_openid.decode_token(
                token,
                key=self.public_key,
                options={
                    'verify_signature': True,
                    'verify_aud': True,
                    'verify_exp': True,
                    'verify_iat': True,
                }
            )
            return token_info
        except Exception as e:
            raise ValueError(f"Token verification failed: {str(e)}")

    async def exchange_token(self, token: str):
        """Exchange token from mobile app to service token"""
        try:
            exchange_params = {
                'grant_type': 'urn:ietf:params:oauth:grant-type:token-exchange',
                'client_id': os.getenv('KEYCLOAK_SOURCE_CLIENT_ID'),
                'client_secret': os.getenv('KEYCLOAK_CLIENT_SECRET'),
                'subject_token': token,
                'aud': "account",
                'requested_token_type': 'urn:ietf:params:oauth:token-type:refresh_token',
                'audience': os.getenv('KEYCLOAK_CLIENT_ID'),
                'scope': 'openid'
            }
            
            url = f"{os.getenv('KEYCLOAK_URL')}/realms/{os.getenv('KEYCLOAK_REALM')}/protocol/openid-connect/token"
            async with httpx.AsyncClient() as client:
                response = await client.post(url, data=exchange_params)
                result = response.json()
            
            if 'error' in result:
                raise KeycloakError(f"Token exchange failed: {result.get('error_description', result['error'])}")
                
            return result
        except Exception as e:
            raise ValueError(f"Token exchange failed: {str(e)}")

    async def introspect_token(self, token: str):
        """Introspect token to check if it's still valid"""
        try:
            params = {
                'token': token,
                'client_id': os.getenv('KEYCLOAK_CLIENT_ID'),
                'client_secret': os.getenv('KEYCLOAK_CLIENT_SECRET')
            }
            
            url = f"{os.getenv('KEYCLOAK_URL')}/realms/{os.getenv('KEYCLOAK_REALM')}/protocol/openid-connect/token/introspect"
            async with httpx.AsyncClient() as client:
                response = await client.post(url, data=params)
                return response.json()
        except Exception as e:
            raise ValueError(f"Token introspection failed: {str(e)}") 