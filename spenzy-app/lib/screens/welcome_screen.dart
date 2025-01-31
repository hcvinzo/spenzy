import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _authService = AuthService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final isAuthenticated = await _authService.isAuthenticated();
    if (mounted) {
      if (isAuthenticated) {
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleAuth({required bool isRegister}) async {
    try {
      await _authService.login(context, isRegister: isRegister);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Authentication failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Text(
                'Invoice Parser',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Track your expenses easily',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => _handleAuth(isRegister: false),
                child: const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Login'),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => _handleAuth(isRegister: true),
                child: const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Register'),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
} 