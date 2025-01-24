import 'dart:io';
import 'package:flutter/material.dart';
import 'package:grpc/grpc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/auth_service.dart';
import '../../services/document_service.dart';
import '../auth/keycloak_webview.dart';
import '../document/document_result_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _authService = AuthService();
  final _documentService = DocumentService();
  late final ClientChannel _channel;
  Map<String, dynamic>? _userInfo;
  bool _isLoading = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _setupServices();
    _loadUserInfo();
  }

  void _setupServices() {
    _channel = ClientChannel(
      'localhost',  // Replace with your server host
      port: 50051,  // Replace with your server port
      options: const ChannelOptions(
        credentials: ChannelCredentials.insecure(),
      ),
    );
  }

  @override
  void dispose() {
    _channel.shutdown();
    super.dispose();
  }

  Future<void> _loadUserInfo() async {
    final userInfo = await _authService.getUserInfo();
    if (mounted) {
      setState(() {
        _userInfo = userInfo;
        _isLoading = false;
      });
    }
  }

  Future<void> _processDocument(File file) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final response = await _documentService.parseDocument(file.path);
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DocumentResultScreen(
              result: DocumentResponse.fromProto(response),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to process document: $e')),
        );
      }
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final image = await ImagePicker().pickImage(source: source);
      if (image == null) return;

      await _processDocument(File(image.path));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'tiff', 'tif'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;
      final file = File(result.files.first.path!);
      await _processDocument(file);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick file: $e')),
        );
      }
    }
  }

  Future<void> _showDocumentPicker() async {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.file_present),
                title: const Text('Choose Document'),
                subtitle: const Text('PDF, JPG, PNG, TIFF'),
                onTap: () {
                  Navigator.pop(context);
                  _pickFile();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showPasswordResetDialog() async {
    if (_userInfo == null) return;

    final email = _userInfo!['email'] as String?;
    if (email == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email not found')),
        );
      }
      return;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Password'),
        content: Text('Send password reset email to $email?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                Navigator.pop(context);
                await _authService.initiatePasswordReset(email);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Password reset email sent'),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to send reset email: $e'),
                    ),
                  );
                }
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  Future<void> _showChangePassword() async {
    try {
      final url = await _authService.getAccountUrl();
      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => KeycloakWebView(
            initialUrl: url,
            onAuthCallback: (_) async {
              Navigator.pop(context);
            },
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open password change: $e')),
        );
      }
    }
  }

  String _getInitials(Map<String, dynamic> userInfo) {
    final firstName = userInfo['given_name'] as String? ?? '';
    final lastName = userInfo['family_name'] as String? ?? '';
    
    if (firstName.isEmpty && lastName.isEmpty) {
      return (userInfo['preferred_username'] as String? ?? '?')[0].toUpperCase();
    }

    return ((firstName.isNotEmpty ? firstName[0] : '') +
            (lastName.isNotEmpty ? lastName[0] : ''))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice Parser'),
        actions: [
          PopupMenuButton<String>(
            offset: const Offset(0, 56),
            position: PopupMenuPosition.under,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: _isLoading
                  ? const SizedBox(
                      width: 36,
                      height: 36,
                      child: CircularProgressIndicator(),
                    )
                  : CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: Text(
                        _userInfo != null ? _getInitials(_userInfo!) : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ),
            itemBuilder: (BuildContext context) => [
              if (_userInfo != null)
                PopupMenuItem<String>(
                  enabled: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_userInfo!['given_name'] ?? ''} ${_userInfo!['family_name'] ?? ''}'.trim(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      Text(
                        _userInfo!['email'] ?? '',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const Divider(),
                    ],
                  ),
                ),
              const PopupMenuItem<String>(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person),
                    SizedBox(width: 8),
                    Text('Profile'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'change_password',
                child: Row(
                  children: [
                    Icon(Icons.key),
                    SizedBox(width: 8),
                    Text('Change Password'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'reset_password',
                child: Row(
                  children: [
                    Icon(Icons.lock_reset),
                    SizedBox(width: 8),
                    Text('Reset Password'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout),
                    SizedBox(width: 8),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
            onSelected: (value) async {
              switch (value) {
                case 'profile':
                  Navigator.pushNamed(context, '/profile');
                  break;
                case 'change_password':
                  await _showChangePassword();
                  break;
                case 'reset_password':
                  await _showPasswordResetDialog();
                  break;
                case 'logout':
                  await _authService.logout();
                  if (context.mounted) {
                    Navigator.of(context).pushReplacementNamed('/');
                  }
                  break;
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          const Center(
            child: Text('Welcome to Invoice Parser'),
          ),
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isProcessing ? null : _showDocumentPicker,
        child: const Icon(Icons.document_scanner),
      ),
    );
  }
} 