import asyncio
import grpc
from concurrent import futures
from proto import expense_pb2_grpc
from app.grpc_services.expense_service import ExpenseServicer
from app.grpc_services.category_service import CategoryServicer

def serve():
    # Create a gRPC server
    server = grpc.server(futures.ThreadPoolExecutor(max_workers=10))
    
    # Add our services to the server
    expense_pb2_grpc.add_ExpenseServiceServicer_to_server(
        ExpenseServicer(), server
    )
    expense_pb2_grpc.add_CategoryServiceServicer_to_server(
        CategoryServicer(), server
    )
    
    # Add secure port for server
    server.add_insecure_port('[::]:50051')
    
    # Start the server
    server.start()
    print("Server started on port 50051")
    
    # Keep the server running
    server.wait_for_termination()

if __name__ == '__main__':
    serve() 