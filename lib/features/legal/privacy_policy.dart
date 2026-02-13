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

3. ON-DEVICE AI MODELS
The App offers optional AI models that run entirely on your device. When using on-device models:
- All AI processing happens locally on your device. No conversation data, prompts, or generated content is sent to external servers.
- Downloaded model files are stored in the App's internal storage on your device.
- Model downloads require an internet connection and data transfer from third-party repositories (such as Hugging Face). Only model weight files are downloaded; no personal data is uploaded during this process.
- On-device AI models are provided by third parties, including Alibaba Cloud (Qwen). These models are pre-trained and do not learn from or retain your data.

4. THIRD-PARTY SERVICES
The App connects to the following external services:

- Anthropic API (cloud AI): Your conversations are sent to Anthropic's servers using your API key. Anthropic's privacy policy applies. This only applies when using cloud models; on-device models do not send data to Anthropic.
- Google Services (optional): If you sign in with Google, the App accesses Google APIs (Calendar, Gmail) using your account. Google's privacy policy applies.
- Hugging Face (model downloads): When you download an on-device AI model, model weight files are fetched from Hugging Face repositories. No personal data is sent. Hugging Face's privacy policy applies to the download.
- Firebase Analytics & Crashlytics: Anonymous usage statistics and crash reports are collected to improve the app. This includes which features are used, error rates, and performance metrics. No personal data or conversation content is included.

5. NO ACCOUNT SYSTEM
The App does not require account creation. Google sign-in is optional and solely for accessing Google services.

6. DATA CONTROL
You have full control over your data. You can:
- Delete your API key from the App at any time.
- Clear conversation history through the App.
- Delete downloaded AI models through the App's settings.
- Disconnect your Google account at any time.
- Uninstall the App to remove all local data, including downloaded models.

7. CHILDREN
The App is not intended for children under 16.

8. CHANGES
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
