#!/bin/bash

# Exit on any error
set -e

# Set paths
FLUTTER_APP_PATH="../../spenzy-app"
DOCUMENT_SERVICE_PATH="../../spenzy-document-service"
PROTO_OUT_DIR="$FLUTTER_APP_PATH/lib/generated/proto"

# Create necessary directories
mkdir -p "$PROTO_OUT_DIR/expense"
mkdir -p "$PROTO_OUT_DIR/google/protobuf"

echo "Generating Python gRPC code for expense service..."
python -m grpc_tools.protoc \
    -I. \
    -I/usr/local/include \
    --python_out=. \
    --grpc_python_out=. \
    expense.proto \
    auth.proto

# Fix imports in generated files
sed -i '' 's/import expense_pb2/from . import expense_pb2/' expense_pb2_grpc.py
sed -i '' 's/import auth_pb2/from . import auth_pb2/' auth_pb2_grpc.py

echo "Python gRPC code generated successfully for expense service."

# Generate Python gRPC code for document service if it exists
if [ -d "$DOCUMENT_SERVICE_PATH" ]; then
    echo "Generating Python gRPC code for document service..."
    mkdir -p "$DOCUMENT_SERVICE_PATH/proto"
    python -m grpc_tools.protoc \
        -I. \
        -I/usr/local/include \
        --python_out="$DOCUMENT_SERVICE_PATH/proto" \
        --grpc_python_out="$DOCUMENT_SERVICE_PATH/proto" \
        expense.proto

    # Fix imports in generated files for document service
    if [ -f "$DOCUMENT_SERVICE_PATH/proto/expense_pb2_grpc.py" ]; then
        sed -i '' 's/import expense_pb2/from . import expense_pb2/' "$DOCUMENT_SERVICE_PATH/proto/expense_pb2_grpc.py"
    fi
    echo "Python gRPC code generated successfully for document service."
else
    echo "Document service directory not found at $DOCUMENT_SERVICE_PATH, skipping..."
fi

# Check if Flutter app directory exists
if [ ! -d "$FLUTTER_APP_PATH" ]; then
    echo "Error: Flutter app directory not found at $FLUTTER_APP_PATH"
    exit 1
fi

echo "Generating Dart gRPC code..."

# First, generate Google protobuf files if they don't exist
if [ ! -f "$PROTO_OUT_DIR/google/protobuf/timestamp.pb.dart" ]; then
    protoc \
        -I/usr/local/include \
        --dart_out="$PROTO_OUT_DIR" \
        google/protobuf/timestamp.proto \
        google/protobuf/duration.proto
fi

# Then generate service protos
protoc \
    -I. \
    -I/usr/local/include \
    -I"$PROTO_OUT_DIR" \
    --dart_out=grpc:"$PROTO_OUT_DIR/expense" \
    expense.proto \
    auth.proto

# Fix import paths in generated Dart files
for file in "$PROTO_OUT_DIR/expense"/*.dart; do
    if [ -f "$file" ]; then
        sed -i '' "s|import 'google/protobuf/|import '../google/protobuf/|g" "$file"
    fi
done

echo "Setting file permissions..."
chmod 644 "$PROTO_OUT_DIR/expense/"*
chmod 644 "$PROTO_OUT_DIR/google/protobuf/"*

if [ -d "$DOCUMENT_SERVICE_PATH" ]; then
    chmod 644 "$DOCUMENT_SERVICE_PATH/proto/"*pb2*.py
fi

echo "All proto files generated successfully!" 