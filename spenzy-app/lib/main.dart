import 'package:flutter/material.dart';
import 'screens/home/home_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'services/auth_service.dart';
import 'widgets/auth_wrapper.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Invoice Parser',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
      onGenerateRoute: (settings) {
        // Handle deep link
        if (settings.name != null && settings.name!.startsWith('/callback')) {
          final uri = Uri.parse(settings.name!.replaceFirst('/', ''));
          return MaterialPageRoute(
            builder: (context) => CallbackHandler(uri: uri),
          );
        }

        // Handle other routes
        switch (settings.name) {
          case '/home':
            return MaterialPageRoute(builder: (_) => const HomeScreen());
          case '/profile':
            return MaterialPageRoute(builder: (_) => const ProfileScreen());
          default:
            return null;
        }
      },
    );
  }
}

class CallbackHandler extends StatefulWidget {
  final Uri uri;

  const CallbackHandler({
    super.key,
    required this.uri,
  });

  @override
  State<CallbackHandler> createState() => _CallbackHandlerState();
}

class _CallbackHandlerState extends State<CallbackHandler> {
  @override
  void initState() {
    super.initState();
    _handleCallback();
  }

  Future<void> _handleCallback() async {
    try {
      final authService = AuthService();
      final success = await authService.handleAuthCallback(widget.uri);
      
      if (mounted && success) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Authentication failed: $e')),
        );
        // Instead of navigating to login screen, trigger Keycloak login
        final authService = AuthService();
        await authService.login(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
