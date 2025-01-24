# Spenzy

Spenzy is a modern expense management application that uses OCR to automatically extract information from receipts and invoices. The application consists of three main components:

1. **Spenzy App (Flutter)**: A cross-platform mobile application for managing expenses and documents
2. **Document Service (Python)**: A gRPC service for document processing and OCR
3. **Expense Service (Python)**: A gRPC service for expense management

## Project Structure

```
spenzy/
├── spenzy-app/           # Flutter mobile application
├── spenzy-document-service/  # Document processing service
└── spenzy-expense-service/   # Expense management service
```

## Prerequisites

- Flutter SDK (latest stable version)
- Python 3.8+
- Docker (optional)
- Keycloak Server (for authentication)

## Setup

### 1. Keycloak Setup

1. Install and run Keycloak server
2. Create a new realm called `InvoiceParser`
3. Create a new client called `spenzy-app`
4. Configure the client:
   - Enable "Authorization Code + PKCE" flow
   - Add redirect URI: `spenzy://auth`
   - Enable "Client authentication"

### 2. Document Service

```bash
cd spenzy-document-service
python -m venv venv
source venv/bin/activate  # or `venv\Scripts\activate` on Windows
pip install -r requirements.txt
python -m grpc_tools.protoc -I./proto --python_out=. --grpc_python_out=. proto/document.proto
python main.py
```

### 3. Expense Service

```bash
cd spenzy-expense-service
python -m venv venv
source venv/bin/activate  # or `venv\Scripts\activate` on Windows
pip install -r requirements.txt
python -m grpc_tools.protoc -I./proto --python_out=. --grpc_python_out=. proto/expense.proto
python main.py
```

### 4. Flutter App

```bash
cd spenzy-app
flutter pub get
./proto/generate_proto.sh  # Generate Dart gRPC code
flutter run
```

## Authentication Flow

1. User logs in through Keycloak using OAuth2 with PKCE
2. App exchanges Keycloak token with Document and Expense services
3. Services validate tokens and provide access to protected resources

## Features

- Document OCR and parsing
- Expense tracking and management
- Multi-service authentication
- Cross-platform support (iOS & Android)

## Development

### Generating Proto Files

For Document Service:
```bash
cd spenzy-document-service/proto
./generate_proto.sh
```

For Expense Service:
```bash
cd spenzy-expense-service/proto
./generate_proto.sh
```

For Flutter App:
```bash
cd spenzy-app
./proto/generate_proto.sh
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details. 