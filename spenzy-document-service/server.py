import os
import grpc
from concurrent import futures
from dotenv import load_dotenv
from proto import document_pb2
from proto import document_pb2_grpc
from app.grpc_services.document_service import DocumentService
from spenzy_common.middleware.auth_interceptor import AuthInterceptor
from app.grpc_services.auth_service import AuthService
from proto import auth_pb2, auth_pb2_grpc

# Load environment variables
load_dotenv()

def serve():
    # Define methods that don't require authentication
    excluded_methods = [
        '/auth.AuthService/Authenticate',  # Allow authentication without token
        '/auth.AuthService/RefreshToken',  # Allow token refresh without token
        '/auth.AuthService/ExchangeToken',  # Allow token exchange without token
        '/grpc.reflection.v1alpha.ServerReflection/ServerReflectionInfo'  # Exclude reflection service
    ]

    # Create gRPC server
    server = grpc.server(
        futures.ThreadPoolExecutor(max_workers=10),
        interceptors=[AuthInterceptor(excluded_methods=excluded_methods)],
        options=[
            ('grpc.max_send_message_length', 50 * 1024 * 1024),  # 50MB
            ('grpc.max_receive_message_length', 50 * 1024 * 1024)  # 50MB
        ]
    )

    # Add services
    document_pb2_grpc.add_DocumentServiceServicer_to_server(DocumentService(), server)
    auth_pb2_grpc.add_AuthServiceServicer_to_server(AuthService(), server)

    # Add reflection service
    from grpc_reflection.v1alpha import reflection
    SERVICE_NAMES = (
        document_pb2.DESCRIPTOR.services_by_name['DocumentService'].full_name,
        auth_pb2.DESCRIPTOR.services_by_name['AuthService'].full_name,
        reflection.SERVICE_NAME,
    )
    reflection.enable_server_reflection(SERVICE_NAMES, server)

    # Start server
    port = os.getenv('GRPC_PORT', '50051')
    server.add_insecure_port(f'[::]:{port}')
    server.start()
    print(f'Server started on port {port}')
    server.wait_for_termination()

if __name__ == '__main__':
    serve()
