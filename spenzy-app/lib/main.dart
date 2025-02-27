import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:spenzy_app/providers/loading_provider.dart';
import 'screens/home_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/welcome_screen.dart';
import 'services/auth_service.dart';
import 'widgets/auth_wrapper.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LoadingProvider(),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Color(0xFF39AE9A), // Background color (Android)
          statusBarIconBrightness: Brightness.light, // Icons color (Android)
          statusBarBrightness: Brightness.dark, // Icons color (iOS)
        ),
        child: MaterialApp(
          title: 'Spenzy',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF39AE9A),
                surface: const Color(0xFF212029)),
            fontFamily: "Poppins",
            useMaterial3: true,
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF39AE9A),
              elevation: 0,
              foregroundColor: Colors.white,
              iconTheme: IconThemeData(color: Colors.white),
            ),
          ),
          home: const AuthWrapper(),
          onGenerateRoute: (settings) {
            // Handle deep link
            if (settings.name != null &&
                settings.name!.startsWith('/callback')) {
              final uri = Uri.parse(settings.name!.replaceFirst('/', ''));
              return MaterialPageRoute(
                builder: (context) => CallbackHandler(uri: uri),
              );
            }

            // Handle other routes
            switch (settings.name) {
              case '/':
                return MaterialPageRoute(builder: (_) => const WelcomeScreen());
              case '/home':
                return MaterialPageRoute(builder: (_) => const HomeScreen());
              case '/profile':
                return MaterialPageRoute(builder: (_) => const ProfileScreen());
              default:
                return MaterialPageRoute(builder: (_) => const WelcomeScreen());
            }
          },
        ),
      ),
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

      if (mounted) {
        if (success) {
          Navigator.of(context)
              .pushNamedAndRemoveUntil('/home', (route) => false);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Authentication failed')),
          );
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Authentication failed: $e')),
        );
        // Navigate back to welcome screen instead of triggering login again
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
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
