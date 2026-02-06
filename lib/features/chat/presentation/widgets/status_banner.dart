import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../shared/widgets/spinner.dart';

/// Status banner showing connection state or processing status
class StatusBanner extends StatelessWidget {
  final String message;
  final bool isError;
  final VoidCallback? onRetry;

  const StatusBanner({
    super.key,
    required this.message,
    this.isError = false,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: isError
          ? NavixTheme.error.withOpacity(0.15)
          : NavixTheme.surface,
      child: Row(
        children: [
          if (isError)
            Text(
              NavixTheme.iconWarning,
              style: TextStyle(
                fontSize: 16,
                color: NavixTheme.error,
              ),
            )
          else
            const BrailleSpinner(size: 16),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isError
                    ? NavixTheme.error
                    : NavixTheme.textSecondary,
              ),
            ),
          ),
          if (isError && onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }
}
