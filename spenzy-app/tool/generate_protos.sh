#!/bin/bash

# Create necessary directories
mkdir -p ./lib/generated/proto

# Generate Dart code from proto files
for proto_file in ./proto/*.proto; do
  if [ -f "$proto_file" ]; then
    echo "Generating Dart code for: $proto_file"
    protoc --dart_out=grpc:./lib/generated/proto \
           --proto_path=./proto \
           "$proto_file"
  fi
done

echo "Proto generation completed!" 