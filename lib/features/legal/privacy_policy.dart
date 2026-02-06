import 'package:flutter/material.dart';

import 'package:navixmind/app/theme.dart';

/// Privacy Policy screen for NavixMind.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const String privacyText = '''
PRIVACY POLICY
Last updated: February 2025

NavixMind ("the App") is an open-source Android application. Your privacy is important. This policy explains how the App handles data.

1. DATA COLLECTION
The developer does not have access to your conversations, files, or personal data. We collect anonymous usage analytics and crash reports via Firebase to improve the app. This includes feature usage statistics, error reports, and performance metrics. No personal information, conversation content, or API keys are ever collected.

2. YOUR DATA
Your API key, conversation history, settings, and processed files are stored on your device. You can delete all app data at any time through your device settings.

3. THIRD-PARTY SERVICES
The App connects to the following external services:

- Anthropic API: Your conversations are sent to Anthropic's servers using your API key. Anthropic's privacy policy applies.
- Google Services (optional): If you sign in with Google, the App accesses Google APIs (Calendar, Gmail) using your account. Google's privacy policy applies.
- Firebase Analytics & Crashlytics: Anonymous usage statistics and crash reports are collected to improve the app. This includes which features are used, error rates, and performance metrics. No personal data or conversation content is included.

4. NO ACCOUNT SYSTEM
The App does not require account creation. Google sign-in is optional and solely for accessing Google services.

5. DATA CONTROL
You have full control over your data. You can:
- Delete your API key from the App at any time.
- Clear conversation history through the App.
- Disconnect your Google account at any time.
- Uninstall the App to remove all local data.

6. CHILDREN
The App is not intended for children under 16.

7. CHANGES
This policy may be updated at any time. Continued use constitutes acceptance.

Contact: support@navixmind.ai''';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NavixTheme.background,
      appBar: AppBar(
        backgroundColor: NavixTheme.background,
        title: const Text('Privacy Policy'),
        leading: IconButton(
          icon: Text(
            NavixTheme.iconClose,
            style: TextStyle(
              fontSize: 24,
              color: NavixTheme.textPrimary,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Text(
          privacyText,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: NavixTheme.textPrimary,
                height: 1.6,
              ),
        ),
      ),
    );
  }
}
