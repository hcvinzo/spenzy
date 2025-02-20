import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spenzy_app/providers/loading_provider.dart';

class LoadingOverlay extends StatelessWidget {
  final String? message;

  const LoadingOverlay({
    super.key,
    this.message = 'Please wait',
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<LoadingProvider>(
        builder: (context, loadingProvider, child) {
      if (!loadingProvider.isLoading) return const SizedBox.shrink();

      return Stack(
        children: [
          // Blocks interactions
          ModalBarrier(
            dismissible: false, // Prevents taps on buttons, etc.
            color: Colors.black.withValues(alpha: 0.3), // Dim effect
          ),
          Container(
            color: Colors.black.withValues(alpha: .7),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF2b2c34),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      color: Color(0xFF39AE9A),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      message ?? 'Please wait',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    });
  }
}
