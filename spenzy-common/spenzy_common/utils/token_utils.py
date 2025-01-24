import grpc
import jwt

def get_user_id_from_context(context):
    """Extract user ID (sub) from the JWT token in metadata.
    
    Args:
        context: The gRPC context containing the request metadata
        
    Returns:
        str: The user ID (sub) from the JWT token
        
    Raises:
        grpc.RpcError: If token is missing, invalid, or doesn't contain a sub claim
    """
    metadata = dict(context.invocation_metadata())
    token = metadata.get('authorization', '').replace('Bearer ', '')
    if not token:
        raise grpc.RpcError(grpc.StatusCode.UNAUTHENTICATED, 'No token provided')
    
    # Decode token without verification since it's already verified by the interceptor
    try:
        decoded = jwt.decode(token, options={"verify_signature": False})
        user_id = decoded.get('sub')
        if not user_id:
            raise grpc.RpcError(grpc.StatusCode.UNAUTHENTICATED, 'Invalid token: no sub claim')
        return user_id
    except jwt.InvalidTokenError as e:
        raise grpc.RpcError(grpc.StatusCode.UNAUTHENTICATED, f'Invalid token: {str(e)}') 