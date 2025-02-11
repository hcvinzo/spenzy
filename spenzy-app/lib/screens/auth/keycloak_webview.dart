import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class KeycloakWebView extends StatefulWidget {
  final String initialUrl;
  final Function(Uri) onAuthCallback;
  final Function(String) onError;

  const KeycloakWebView({
    super.key,
    required this.initialUrl,
    required this.onAuthCallback,
    required this.onError,
  });

  @override
  State<KeycloakWebView> createState() => _KeycloakWebViewState();
}

class _KeycloakWebViewState extends State<KeycloakWebView> {
  late final WebViewController _controller;
  bool _isLoading = true;
  Timer? _loadingTimer;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _initWebView();
    _startLoadingTimer();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _loadingTimer?.cancel();
    super.dispose();
  }

  void _handleError(String error) {
    if (!_isDisposed && mounted && context.mounted) {
      widget.onError(error);
    }
  }

  void _startLoadingTimer() {
    _loadingTimer?.cancel();
    _loadingTimer = Timer(const Duration(seconds: 30), () {
      if (!_isDisposed && mounted) {
        _handleError('Login timeout. Please try again.');
      }
    });
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onUrlChange: (UrlChange change) {
            if (change.url != null && change.url!.startsWith('spenzy://auth')) {
              _loadingTimer?.cancel();
              widget.onAuthCallback(Uri.parse(change.url!));
            }
          },
          onPageStarted: (String url) {
            if (url.startsWith('spenzy://auth')) {
              // Don't show loading for callback URL
              return;
            }
            
            if (!_isDisposed && mounted) {
              setState(() {
                _isLoading = true;
              });
              _startLoadingTimer();
            }
          },
          onPageFinished: (String url) {
            if (!_isDisposed && mounted) {
              setState(() {
                _isLoading = false;
              });
              _loadingTimer?.cancel();
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            if (request.url.startsWith('spenzy://auth')) {
              return NavigationDecision.prevent;
            }else{
              return NavigationDecision.navigate;
            }
          },
          onWebResourceError: (WebResourceError error) async {
            // Only handle errors for non-callback URLs
            final currentUrl = await error.url;
            final isCallback = currentUrl?.startsWith('spenzy://auth') ?? false;
            
            if (!isCallback && !_isDisposed && mounted) {
              _loadingTimer?.cancel();
              setState(() {
                _isLoading = false;
              });
              
              String errorMessage = 'Failed to load login page';
              if (error.description.isNotEmpty) {
                errorMessage += ': ${error.description}';
              }
              
              // Add a small delay before calling onError to ensure proper navigation
              Future.delayed(const Duration(milliseconds: 100), () {
                if (!_isDisposed && mounted) {
                  widget.onError(errorMessage);
                }
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.initialUrl));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          _loadingTimer?.cancel();
          _handleError('Login cancelled');
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Login'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              _loadingTimer?.cancel();
              _handleError('Login cancelled');
            },
          ),
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
} 