# Spenzy Document Service

A gRPC service that provides document parsing capabilities with OCR and AI-powered analysis. The service includes JWT authentication and supports various document formats including PDF and images.

## Features

- **Document Processing**
  - OCR text extraction from PDFs and images
  - AI-powered invoice analysis using OpenAI
  - Support for multiple file formats (PDF, JPEG, PNG, TIFF, BMP)
  - Automatic file type detection

- **Authentication & Security**
  - JWT-based authentication
  - API key validation for initial authentication
  - Refresh token functionality
  - Secure token handling

- **gRPC Features**
  - Server reflection enabled for easy testing
  - File streaming support
  - Authentication interceptors
  - Configurable message size limits

## Prerequisites

- Python 3.12
- Tesseract OCR
- OpenAI API key
- Virtual environment (recommended)

## Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd spenzy-document-service
```

2. Create and activate a virtual environment:
```bash
python3.12 -m venv venv
source venv/bin/activate  # On Unix/macOS
# or
.\venv\Scripts\activate  # On Windows
```

3. Install dependencies:
```bash
pip install -r requirements.txt
```

4. Install Tesseract OCR:
```bash
# macOS
brew install tesseract

# Ubuntu/Debian
sudo apt-get install tesseract-ocr

# Windows
# Download installer from https://github.com/UB-Mannheim/tesseract/wiki
```

## Configuration

1. Set up environment variables:
```bash
export OPENAI_API_KEY="your-api-key"
# or create a .env file with:
OPENAI_API_KEY=your-api-key
```

2. Configure JWT settings in `config/config.py`:
```python
JWT_SECRET_KEY = "your-secret-key"
JWT_ALGORITHM = "HS256"
JWT_EXPIRATION_MINUTES = 30
```

## Usage

1. Start the server:
```bash
python server.py
```

2. The server will start on port 50051 (configurable in config.py)

3. Use a gRPC client to interact with the service. Example using grpcurl:

Authentication:
```bash
grpcurl -plaintext -d '{"api_key": "your-api-key"}' localhost:50051 auth.AuthService/Authenticate
```

Parse Document:
```bash
grpcurl -H "Authorization: Bearer your-jwt-token" \
        -d '{"file_content": "base64-encoded-content", "file_name": "invoice.pdf"}' \
        localhost:50051 document.DocumentService/ParseDocument
```

## API Methods

### Auth Service
- `Authenticate`: Initial authentication using API key
- `RefreshToken`: Refresh an expired JWT token

### Document Service
- `ParseDocument`: Process and analyze document files
- `GetDocumentFile`: Retrieve processed document files
- `ParseDocumentText`: Analyze document text directly

## Project Structure

```
.
├── app/
│   ├── grpc_services/          # gRPC service implementations
│   │   ├── auth_service.py
│   │   └── invoice_service.py
│   ├── middleware/             # Middleware components
│   │   └── auth_interceptor.py
│   └── services/              # Business logic
│       └── invoice_parser.py
├── auth/                      # Authentication utilities
│   ├── jwt_handler.py
│   └── api_key_validator.py
├── config/                    # Configuration
│   └── config.py
├── proto/                     # Protocol Buffers definitions
│   ├── auth.proto
│   └── invoice.proto
├── requirements.txt
└── server.py                 # Main server
```

## Development

To regenerate gRPC code after modifying proto files:
```bash
python -m grpc_tools.protoc -I. --python_out=. --grpc_python_out=. proto/*.proto
```

## Error Handling

The service includes comprehensive error handling for:
- Invalid file types
- OCR processing failures
- AI analysis errors
- Authentication failures
- Invalid tokens
- File streaming issues

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

[MIT License](LICENSE) 