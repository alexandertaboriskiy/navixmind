import 'dart:io';

import 'package:flutter/material.dart';

import 'package:navixmind/app/theme.dart';
import 'package:navixmind/core/services/analytics_service.dart';
import 'package:navixmind/core/services/storage_service.dart';
import 'package:navixmind/features/legal/terms_of_service.dart';
import 'package:navixmind/features/legal/privacy_policy.dart';

/// Shows a legal acceptance dialog on first app launch.
///
/// Returns `true` if the user accepted, `false` if declined.
/// Tracks acceptance state using [StorageService].
class LegalAcceptanceDialog {
  /// Check if legal terms need to be shown and display the dialog if needed.
  /// Returns `true` if already accepted or user accepts now.
  /// Returns `false` if user declines.
  static Future<bool> checkAndShow(BuildContext context) async {
    final accepted = await StorageService.instance.isLegalAccepted();
    if (accepted) return true;

    if (!context.mounted) return false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _LegalDialog(),
    );

    if (result == true) {
      await StorageService.instance.setLegalAccepted(true);
      await AnalyticsService.instance.legalAccepted();
      return true;
    }

    await AnalyticsService.instance.legalDeclined();
    return false;
  }

  /// Show declined message and exit the app.
  static void handleDeclined(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'You must accept the Terms of Service and Privacy Policy to use NavixMind.',
        ),
        duration: Duration(seconds: 3),
      ),
    );
    Future.delayed(const Duration(seconds: 3), () => exit(0));
  }
}

class _LegalDialog extends StatefulWidget {
  const _LegalDialog();

  @override
  State<_LegalDialog> createState() => _LegalDialogState();
}

class _LegalDialogState extends State<_LegalDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: NavixTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Text(
              'Legal Terms',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: NavixTheme.textPrimary,
                  ),
            ),
          ),

          const SizedBox(height: 4),

          Text(
            'Please review before continuing',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: NavixTheme.textSecondary,
                ),
          ),

          const SizedBox(height: 12),

          // Tab bar
          TabBar(
            controller: _tabController,
            indicatorColor: NavixTheme.primary,
            labelColor: NavixTheme.primary,
            unselectedLabelColor: NavixTheme.textSecondary,
            tabs: const [
              Tab(text: 'Terms of Service'),
              Tab(text: 'Privacy Policy'),
            ],
          ),

          // Tab content
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.45,
            child: TabBarView(
              controller: _tabController,
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    TermsOfServiceScreen.tosText,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: NavixTheme.textPrimary,
                          height: 1.5,
                          fontSize: 12,
                        ),
                  ),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    PrivacyPolicyScreen.privacyText,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: NavixTheme.textPrimary,
                          height: 1.5,
                          fontSize: 12,
                        ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('I Accept'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
