import os
import grpc
from proto import expense_pb2
from proto import expense_pb2_grpc

class CategoryClient:
    def __init__(self):
        self.channel = grpc.insecure_channel('localhost:50052')
        self.stub = expense_pb2_grpc.CategoryServiceStub(self.channel)

    def get_categories(self, context):
        try:
            # Extract token from metadata
            metadata = dict(context.invocation_metadata())
            auth_header = metadata.get('authorization', '')
            if not auth_header.startswith('Bearer '):
                raise ValueError('Invalid authorization header')
            
            token = auth_header.split(' ')[1]
            # Create gRPC metadata for the outgoing request
            metadata = [('authorization', f'Bearer {token}')]
            
            request = expense_pb2.ListCategoriesRequest()
            response = self.stub.ListCategories(request, metadata=metadata)
            # Return only category names since that's what document_parser.py expects
            return [cat.name for cat in response.categories]
        except grpc.RpcError as e:
            print(f"Failed to fetch categories: {str(e)}")
            # Return default categories as fallback
            return [
                "Groceries", "Restaurants", "Electricity", "Communication",
                "Water", "Gas/Fuel", "Clothing", "Medical/Healthcare",
                "Household Items/Supplies", "Personal", "Education",
                "Entertainment", "Others"
            ]
        except Exception as e:
            print(f"Unexpected error while fetching categories: {str(e)}")
            return []

    def close(self):
        self.channel.close() 