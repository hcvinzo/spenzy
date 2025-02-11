import os
import asyncio
import signal
from dotenv import load_dotenv
import grpc
from grpc_reflection.v1alpha import reflection
from proto import expense_pb2, expense_pb2_grpc
from app.grpc_services.expense_service import ExpenseServicer
from app.grpc_services.category_service import CategoryServicer
from app.grpc_services.tag_service import TagServicer
from spenzy_common.middleware.auth_interceptor import AuthInterceptor
from app.grpc_services.auth_service import AuthService
from proto import auth_pb2, auth_pb2_grpc
from app.database import init_db

# Load environment variables
load_dotenv()

async def serve():
    # Initialize database first
    await init_db()

    # Define methods that don't require authentication
    excluded_methods = [
        '/auth.AuthService/Authenticate',  # Allow initial authentication
        '/auth.AuthService/RefreshToken',  # Allow token refresh
        '/auth.AuthService/ExchangeToken',  # Allow token exchange
        '/grpc.reflection.v1alpha.ServerReflection/ServerReflectionInfo'  # Exclude reflection service
    ]

    # Initialize the gRPC server with message size limits and interceptor
    server = grpc.aio.server(
        interceptors=[AuthInterceptor(excluded_methods=excluded_methods)],
        options=[
            ('grpc.max_send_message_length', 50 * 1024 * 1024),
            ('grpc.max_receive_message_length', 50 * 1024 * 1024)
        ]
    )

    # Add the expense service
    expense_service = ExpenseServicer()
    expense_pb2_grpc.add_ExpenseServiceServicer_to_server(expense_service, server)

    # Add the category service
    category_service = CategoryServicer()
    expense_pb2_grpc.add_CategoryServiceServicer_to_server(category_service, server)

    # Add the tag service
    tag_service = TagServicer()
    expense_pb2_grpc.add_TagServiceServicer_to_server(tag_service, server)

    # Add the auth service
    auth_service = AuthService()
    auth_pb2_grpc.add_AuthServiceServicer_to_server(auth_service, server)

    # Enable reflection
    SERVICE_NAMES = (
        expense_pb2.DESCRIPTOR.services_by_name['ExpenseService'].full_name,
        expense_pb2.DESCRIPTOR.services_by_name['CategoryService'].full_name,
        expense_pb2.DESCRIPTOR.services_by_name['TagService'].full_name,
        auth_pb2.DESCRIPTOR.services_by_name['AuthService'].full_name,
        reflection.SERVICE_NAME,
    )
    reflection.enable_server_reflection(SERVICE_NAMES, server)

    # Start the server
    port = os.getenv('GRPC_PORT', '50052')
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