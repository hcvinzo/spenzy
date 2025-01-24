import os
from dotenv import load_dotenv
import grpc
from concurrent import futures
from grpc_reflection.v1alpha import reflection
from proto import expense_pb2, expense_pb2_grpc
from app.grpc_services.expense_service import ExpenseService
from spenzy_common.middleware.auth_interceptor import AuthInterceptor
from app.grpc_services.auth_service import AuthService
from proto import auth_pb2, auth_pb2_grpc
from app.database import init_db

# Load environment variables
load_dotenv()

# Initialize database
init_db()

def serve():
    # Define methods that don't require authentication
    excluded_methods = [
        '/auth.AuthService/Authenticate',  # Allow initial authentication
        '/auth.AuthService/RefreshToken',  # Allow token refresh
        '/auth.AuthService/ExchangeToken',  # Allow token exchange
        '/grpc.reflection.v1alpha.ServerReflection/ServerReflectionInfo'  # Exclude reflection service
    ]

    # Initialize the gRPC server with message size limits and interceptor
    server = grpc.server(
        futures.ThreadPoolExecutor(max_workers=10),
        options=[
            ('grpc.max_send_message_length', 50 * 1024 * 1024),
            ('grpc.max_receive_message_length', 50 * 1024 * 1024)
        ],
        interceptors=[AuthInterceptor(excluded_methods=excluded_methods)]
    )

    # Add the expense service
    expense_service = ExpenseService()
    expense_pb2_grpc.add_ExpenseServiceServicer_to_server(expense_service, server)

    # Add the auth service
    auth_service = AuthService()
    auth_pb2_grpc.add_AuthServiceServicer_to_server(auth_service, server)

    # Enable reflection
    SERVICE_NAMES = (
        expense_pb2.DESCRIPTOR.services_by_name['ExpenseService'].full_name,
        auth_pb2.DESCRIPTOR.services_by_name['AuthService'].full_name,
        reflection.SERVICE_NAME,
    )
    reflection.enable_server_reflection(SERVICE_NAMES, server)

    # Start the server
    port = os.getenv('PORT', '50052')
    server.add_insecure_port(f'[::]:{port}')
    server.start()
    print(f'Server started on port {port}')
    server.wait_for_termination()

if __name__ == '__main__':
    serve() 