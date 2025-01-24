#!/bin/bash

# Exit on any error
set -e

# Set paths
FLUTTER_APP_PATH="../../spenzy-app"
PROTO_OUT_DIR="$FLUTTER_APP_PATH/lib/generated/proto"

# Create necessary directories
mkdir -p "$PROTO_OUT_DIR/document"
mkdir -p "$PROTO_OUT_DIR/google/protobuf"

echo "Generating Python gRPC code..."
python -m grpc_tools.protoc \
    -I. \
    -I/usr/local/include \
    --python_out=. \
    --grpc_python_out=. \
    document.proto \
    auth.proto

# Fix imports in generated files
sed -i '' 's/import document_pb2/from . import document_pb2/' document_pb2_grpc.py
sed -i '' 's/import auth_pb2/from . import auth_pb2/' auth_pb2_grpc.py

echo "Python gRPC code generated successfully."

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
    --dart_out=grpc:"$PROTO_OUT_DIR/document" \
    document.proto \
    auth.proto

# Fix import paths in generated Dart files
for file in "$PROTO_OUT_DIR/document"/*.dart; do
    if [ -f "$file" ]; then
        sed -i '' "s|import 'google/protobuf/|import '../google/protobuf/|g" "$file"
    fi
done

echo "Setting file permissions..."
chmod 644 "$PROTO_OUT_DIR/document/"*
chmod 644 "$PROTO_OUT_DIR/google/protobuf/"*

echo "All proto files generated successfully!" 