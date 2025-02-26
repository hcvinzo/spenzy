# Spenzy App

Spenzy is a smart expense tracking and invoice parsing application that helps you manage your finances efficiently. Built with Flutter and modern architecture principles, it provides a seamless experience for managing expenses and processing documents.

## Features

### Expense Management
- Create, view, edit, and delete expenses
- Categorize expenses with custom categories
- Tag expenses for better organization
- Track payment status and due dates
- Multi-currency support
- Monthly expense summaries and analytics

### Document Processing
- Automated invoice parsing using OCR
- Support for multiple document formats (PDF, JPG, PNG)
- Extract key information automatically:
  - Vendor details
  - Amount and tax information
  - Dates and due dates
  - Currency

### User Interface
- Modern and intuitive Material Design
- Dark theme optimized for OLED displays
- Responsive layout supporting multiple screen sizes
- Loading overlays for better UX during operations
- Pull-to-refresh for data updates

### Security & Authentication
- Secure authentication with Keycloak
- Token-based API access
- Secure storage for sensitive data
- Auto-refresh of expired tokens

## Architecture

### State Management
- Provider pattern for app-wide state
- Local state management with StatefulWidget where appropriate

### Services
- gRPC communication with backend services
- Dedicated service classes for:
  - Expense management
  - Document processing
  - Category management
  - Authentication

### Data Models
- Protocol Buffers for type-safe API communication
- Clean separation of data and presentation layers

## Getting Started

### Prerequisites
- Flutter SDK (latest stable version)
- Dart SDK
- Android Studio / VS Code with Flutter plugins
- Running instances of:
  - Spenzy Document Service
  - Spenzy Expense Service
  - Keycloak Authentication Server

### Environment Setup
1. Clone the repository
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Configure environment variables:
   - Authentication server URL
   - gRPC service endpoints
   - Client credentials

### Running the App
```bash
# Debug mode
flutter run

# Release mode
flutter run --release
```

## Project Structure
```
lib/
├── generated/        # Generated Protocol Buffer code
├── providers/        # State management providers
├── screens/         # UI screens
│   ├── expense/     # Expense-related screens
│   ├── home/        # Home and dashboard screens
│   └── profile/     # User profile screens
├── services/        # Backend service clients
├── utils/          # Utility functions and helpers
└── widgets/        # Reusable UI components
```

## Dependencies
- `provider`: State management
- `grpc`: gRPC communication
- `protobuf`: Protocol Buffers support
- `flutter_secure_storage`: Secure data storage
- `intl`: Internationalization and formatting
- `file_picker`: Document selection
- `image_picker`: Camera and gallery integration

## Contributing
1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License
This project is proprietary and confidential. All rights reserved.

## Support
For support and questions, please contact the development team.
