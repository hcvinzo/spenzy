import grpc
from spenzy_common.auth.keycloak_handler import KeycloakHandler

class AuthInterceptor(grpc.ServerInterceptor):
    def __init__(self, excluded_methods=None):
        self.keycloak_handler = KeycloakHandler()
        self.excluded_methods = excluded_methods or []

    def intercept_service(self, continuation, handler_call_details):
        method = handler_call_details.method
        
        # Skip authentication for excluded methods
        if method in self.excluded_methods:
            return continuation(handler_call_details)

        metadata = dict(handler_call_details.invocation_metadata)
        auth_header = metadata.get('authorization', '')

        if not auth_header.startswith('Bearer '):
            return self._unauthenticated_response()

        token = auth_header.split(' ')[1]
        try:
            token_info = self.keycloak_handler.verify_token(token)
            # Add user info to the context
            metadata['user_id'] = token_info.get('sub', '')
            metadata['email'] = token_info.get('email', '')
            metadata['username'] = token_info.get('preferred_username', '')
            
            # Create new handler call details with updated metadata
            new_details = handler_call_details.__class__(
                method,
                tuple((k, v) for k, v in metadata.items())
            )
            return continuation(new_details)
        except Exception as e:
            return self._unauthenticated_response(str(e))

    def _unauthenticated_response(self, details='Invalid or missing token'):
        def _abort_unauth(ignored_request, context):
            context.abort(grpc.StatusCode.UNAUTHENTICATED, details)
        return grpc.unary_unary_rpc_method_handler(_abort_unauth) 