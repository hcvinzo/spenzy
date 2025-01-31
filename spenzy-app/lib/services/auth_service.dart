import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'service_auth.dart';
import '../screens/auth/keycloak_webview.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  static const String keycloakUrl = 'http://localhost:8080';
  static const String realm = 'InvoiceParser';
  static const String clientId = 'spenzy-app';
  
  // Keys for secure storage
  static const String tokenKey = 'auth_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String stateKey = 'oauth_state';
  static const String verifierKey = 'code_verifier';
  
  // Create secure storage instance
  final _storage = const FlutterSecureStorage();
  final _serviceAuth = ServiceAuth();

  Future<void> initiatePasswordReset(String email) async {
    final response = await http.post(
      Uri.parse('$keycloakUrl/realms/$realm/login-actions/reset-credentials'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'client_id': clientId,
        'email': email,
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to initiate password reset');
    }
  }

  Future<String> getAccountUrl() async {
    final token = await getToken();
    if (token == null) throw Exception('Not authenticated');
    
    return '$keycloakUrl/realms/$realm/account/#/security/signingin';
  }

  Future<Map<String, dynamic>?> getUserInfo() async {
    final token = await getToken();
    if (token == null) return null;

    try {
      final response = await http.get(
        Uri.parse('$keycloakUrl/realms/$realm/protocol/openid-connect/userinfo'),
        headers: {'Authorization': 'Bearer $token'},
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> isAuthenticated() async {
    final token = await getToken();
    if (token == null) return false;

    try {
      // Verify Keycloak token
      final response = await http.get(
        Uri.parse('$keycloakUrl/realms/$realm/protocol/openid-connect/userinfo'),
        headers: {'Authorization': 'Bearer $token'},
      );
      
      if (response.statusCode != 200) {
        return false;
      }

      // Verify service tokens
      final docToken = await _serviceAuth.getServiceToken('spenzy-document.service');
      final expToken = await _serviceAuth.getServiceToken('spenzy-expense.service');
      
      if (docToken == null || expToken == null) {
        return false;
      }

      final docValid = await _serviceAuth.verifyServiceToken('spenzy-document.service', docToken);
      final expValid = await _serviceAuth.verifyServiceToken('spenzy-expense.service', expToken);

      return docValid && expValid;
    } catch (e) {
      return false;
    }
  }

  Future<String?> getToken() async {
    return await _storage.read(key: tokenKey);
  }

  String _generateCodeVerifier() {
    final random = Random.secure();
    final values = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Url.encode(values).replaceAll('=', '');
  }

  String _generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  Future<void> login(BuildContext context, {bool isRegister = false}) async {
    try {
      final credentials = await _authenticate();

      // Show the WebView for login
      if (context.mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => KeycloakWebView(
              initialUrl: credentials.authUrl,
              onAuthCallback: (callbackUri) async {
                final success = await handleAuthCallback(callbackUri);
                if (success && context.mounted) {
                  // After successful login, exchange tokens for services
                  final token = await getToken();
                  if (token != null) {
                    await _serviceAuth.exchangeToken(token, 'spenzy-document.service');
                    await _serviceAuth.exchangeToken(token, 'spenzy-expense.service');
                  }
                  
                  // Close WebView and navigate to home screen
                  if (context.mounted) {
                    Navigator.of(context).pop(); // Close WebView
                    Navigator.of(context).pushReplacementNamed('/home'); // Navigate to home screen
                  }
                }
              },
            ),
          ),
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: tokenKey);
    await _storage.delete(key: refreshTokenKey);
    await _serviceAuth.clearTokens();
  }

  Future<OAuthCredentials> _authenticate() async {
    final state = const Uuid().v4();
    final verifier = _generateCodeVerifier();
    final challenge = _generateCodeChallenge(verifier);

    await _storage.write(key: stateKey, value: state);
    await _storage.write(key: verifierKey, value: verifier);

    final authUrl = Uri.parse('$keycloakUrl/realms/$realm/protocol/openid-connect/auth').replace(
      queryParameters: {
        'response_type': 'code',
        'client_id': clientId,
        'redirect_uri': 'spenzy://auth',
        'state': state,
        'code_challenge': challenge,
        'code_challenge_method': 'S256',
        'scope': 'openid profile email',
      },
    );

    return OAuthCredentials(authUrl.toString());
  }

  Future<bool> handleAuthCallback(Uri uri) async {
    if (uri.scheme != 'spenzy') return false;

    final storedState = await _storage.read(key: stateKey);
    final verifier = await _storage.read(key: verifierKey);

    if (storedState == null || verifier == null) {
      throw Exception('Missing authentication state');
    }

    final state = uri.queryParameters['state'];
    final code = uri.queryParameters['code'];

    if (state != storedState) {
      throw Exception('Invalid state parameter');
    }

    if (code == null) {
      throw Exception('No code parameter in callback');
    }

    final response = await http.post(
      Uri.parse('$keycloakUrl/realms/$realm/protocol/openid-connect/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'authorization_code',
        'client_id': clientId,
        'code': code,
        'redirect_uri': 'spenzy://auth',
        'code_verifier': verifier,
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to exchange code for token');
    }

    final data = json.decode(response.body);
    await _storage.write(key: tokenKey, value: data['access_token']);
    await _storage.write(key: refreshTokenKey, value: data['refresh_token']);

    return true;
  }
}

class OAuthCredentials {
  final String authUrl;
  String? accessToken;
  String? refreshToken;

  OAuthCredentials(this.authUrl, {this.accessToken, this.refreshToken});
} 