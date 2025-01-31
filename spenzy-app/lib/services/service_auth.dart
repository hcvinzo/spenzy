import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:grpc/grpc.dart';
import 'package:spenzy_app/generated/proto/document/auth.pbgrpc.dart' as document_auth;
import 'package:spenzy_app/generated/proto/expense/auth.pbgrpc.dart' as expense_auth;

class ServiceAuth {
  static final ServiceAuth _instance = ServiceAuth._internal();
  factory ServiceAuth() => _instance;

  ServiceAuth._internal() {
    // Initialize document service client
    _documentChannel = ClientChannel(
      grpcHost,
      port: documentServicePort,
      options: const ChannelOptions(
        credentials: ChannelCredentials.insecure(),
      ),
    );
    _documentAuthClient = document_auth.AuthServiceClient(_documentChannel);

    // Initialize expense service client
    _expenseChannel = ClientChannel(
      grpcHost,
      port: expenseServicePort,
      options: const ChannelOptions(
        credentials: ChannelCredentials.insecure(),
      ),
    );
    _expenseAuthClient = expense_auth.AuthServiceClient(_expenseChannel);
  }

  static const String grpcHost = 'localhost';
  static const int documentServicePort = 50051;
  static const int expenseServicePort = 50052;
  
  // Keys for secure storage
  static const String documentServiceTokenKey = 'document_service_token';
  static const String expenseServiceTokenKey = 'expense_service_token';
  
  // Create secure storage instance
  final _storage = const FlutterSecureStorage();
  
  // gRPC channels and clients for both services
  late final ClientChannel _documentChannel;
  late final ClientChannel _expenseChannel;
  late final document_auth.AuthServiceClient _documentAuthClient;
  late final expense_auth.AuthServiceClient _expenseAuthClient;

  Future<void> dispose() async {
    await _documentChannel.shutdown();
    await _expenseChannel.shutdown();
  }

  // Helper method to create authenticated call options
  CallOptions _createAuthOptions(String token) {
    return CallOptions(metadata: {
      'authorization': 'Bearer $token'
    });
  }

  Future<void> refreshServiceToken(String service, String refreshToken) async {
    try {
      if (service == 'spenzy-document.service') {
        final request = document_auth.RefreshTokenRequest()
          ..refreshToken = refreshToken;
        
        final response = await _documentAuthClient.refreshToken(
          request,
          options: _createAuthOptions(refreshToken)
        );
        
        await _storage.write(key: documentServiceTokenKey, value: response.accessToken);
      } else {
        final request = expense_auth.RefreshTokenRequest()
          ..refreshToken = refreshToken;
        
        final response = await _expenseAuthClient.refreshToken(
          request,
          options: _createAuthOptions(refreshToken)
        );
        
        await _storage.write(key: expenseServiceTokenKey, value: response.accessToken);
      }
    } catch (e) {
      // If refresh fails, clear service token
      final storageKey = service == 'spenzy-document.service' 
          ? documentServiceTokenKey 
          : expenseServiceTokenKey;
          
      await _storage.delete(key: storageKey);
      throw Exception('Failed to refresh service token: $e');
    }
  }

  Future<String?> getServiceToken(String service) async {
    final storageKey = service == 'spenzy-document.service' 
        ? documentServiceTokenKey 
        : expenseServiceTokenKey;
    
    return await _storage.read(key: storageKey);
  }

  Future<String> exchangeToken(String token, String service) async {
    try {
      if (service == 'spenzy-document.service') {
        final request = document_auth.TokenExchangeRequest()
          ..token = token;
        
        final response = await _documentAuthClient.exchangeToken(
          request,
          options: _createAuthOptions(token)
        );
        
        await _storage.write(key: documentServiceTokenKey, value: response.accessToken);
        return response.accessToken;
      } else {
        final request = expense_auth.TokenExchangeRequest()
          ..token = token;
        
        final response = await _expenseAuthClient.exchangeToken(
          request,
          options: _createAuthOptions(token)
        );
        
        await _storage.write(key: expenseServiceTokenKey, value: response.accessToken);
        return response.accessToken;
      }
    } catch (e) {
      throw Exception('Failed to exchange token with service: $e');
    }
  }

  Future<void> clearTokens() async {
    await _storage.delete(key: documentServiceTokenKey);
    await _storage.delete(key: expenseServiceTokenKey);
  }

  Future<bool> verifyServiceToken(String service, String token) async {
    try {
      if (service == 'spenzy-document.service') {
        final request = document_auth.RefreshTokenRequest()
          ..refreshToken = '';
        
        await _documentAuthClient.refreshToken(
          request,
          options: CallOptions(metadata: {
            'authorization': 'Bearer $token',
          }),
        );
      } else {
        final request = expense_auth.RefreshTokenRequest()
          ..refreshToken = '';
        
        await _expenseAuthClient.refreshToken(
          request,
          options: CallOptions(metadata: {
            'authorization': 'Bearer $token',
          }),
        );
      }
      return true;
    } catch (e) {
      return false;
    }
  }
} 