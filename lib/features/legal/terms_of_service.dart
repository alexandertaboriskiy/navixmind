import 'package:flutter/material.dart';

import 'package:navixmind/app/theme.dart';

/// Terms of Service screen for NavixMind.
class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  static const String tosText = '''
TERMS OF SERVICE
Last updated: February 2025

By using NavixMind ("the App"), you agree to these terms. If you do not agree, do not use the App.

1. AS-IS SOFTWARE
THE APP IS PROVIDED "AS IS" AND "AS AVAILABLE" WITHOUT WARRANTIES OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT. THE DEVELOPER MAKES NO GUARANTEES REGARDING UPTIME, RELIABILITY, ACCURACY, OR AVAILABILITY.

2. YOUR API KEY & COSTS
You provide your own Anthropic API key. You are solely responsible for all API usage costs incurred through the App. The developer has no access to your API key and bears no responsibility for charges on your Anthropic account.

3. YOUR CONTENT
You are solely responsible for all content you process, generate, or store using the App. You must comply with Anthropic's Acceptable Use Policy and all applicable laws.

4. DEVICE PERMISSIONS
The App may request access to device resources including storage and network. These are used solely for app functionality. You may revoke permissions at any time through your device settings.

5. LIMITATION OF LIABILITY
TO THE MAXIMUM EXTENT PERMITTED BY LAW, THE DEVELOPER SHALL NOT BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES, INCLUDING BUT NOT LIMITED TO: DATA LOSS, API COSTS, DEVICE DAMAGE, LOSS OF PROFITS, OR ANY OTHER DAMAGES ARISING FROM YOUR USE OF OR INABILITY TO USE THE APP.

6. MODIFICATIONS & TERMINATION
The developer may modify, suspend, or discontinue the App at any time without notice or liability. These terms may be updated at any time; continued use constitutes acceptance.

7. OPEN SOURCE
The App is open-source software. Use of the source code is subject to the applicable open-source license in the repository.

8. GOVERNING LAW
These terms shall be governed by applicable law. Any disputes shall be resolved in the courts of the developer's jurisdiction.

By using NavixMind, you acknowledge that you have read, understood, and agree to these terms.''';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NavixTheme.background,
      appBar: AppBar(
        backgroundColor: NavixTheme.background,
        title: const Text('Terms of Service'),
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
          tosText,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: NavixTheme.textPrimary,
                height: 1.6,
              ),
        ),
      ),
    );
  }
}
