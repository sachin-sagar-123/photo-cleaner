import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Full-screen loading overlay.
class LoadingOverlay extends StatelessWidget {
  final String? message;

  const LoadingOverlay({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background.withOpacity(0.7),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(message!, style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 14)),
            ],
          ],
        ),
      ),
    );
  }
}
