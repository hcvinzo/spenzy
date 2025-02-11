import os
import grpc
import asyncio
import signal
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

async def serve():
    # Define methods that don't require authentication
    excluded_methods = [
        '/auth.AuthService/Authenticate',  # Allow authentication without token
        '/auth.AuthService/RefreshToken',  # Allow token refresh without token
        '/auth.AuthService/ExchangeToken',  # Allow token exchange without token
        '/grpc.reflection.v1alpha.ServerReflection/ServerReflectionInfo'  # Exclude reflection service
    ]

    # Create gRPC server
    server = grpc.aio.server(
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
    listen_addr = f'[::]:{port}'
    server.add_insecure_port(listen_addr)
    await server.start()
    print(f'Server started on port {port}')

    # Handle shutdown gracefully
    shutdown_event = asyncio.Event()

    def signal_handler():
        print("\nReceived shutdown signal")
        shutdown_event.set()

    for sig in (signal.SIGTERM, signal.SIGINT):
        loop = asyncio.get_running_loop()
        loop.add_signal_handler(sig, signal_handler)
    
    try:
        await shutdown_event.wait()
    finally:
        print("\nShutting down server...")
        # Shutdown the gRPC server
        await server.stop(5)  # 5 seconds grace period
        print("Server shutdown complete")

if __name__ == '__main__':
    try:
        asyncio.run(serve())
    except KeyboardInterrupt:
        print("\nShutdown complete")
