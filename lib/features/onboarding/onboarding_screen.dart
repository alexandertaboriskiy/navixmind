import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/services/storage_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  final _apiKeyController = TextEditingController();
  int _currentPage = 0;

  final _pages = [
    const _OnboardingPage(
      icon: '◆',
      title: 'Welcome to NavixMind',
      description:
          'Your AI-powered console agent for Android. Process documents, '
          'manage calendar, and automate tasks with natural language.',
    ),
    const _OnboardingPage(
      icon: '◰',
      title: 'Process Any Media',
      description:
          'Extract text from PDFs, crop videos, and convert documents. '
          'All processing happens on your device.',
    ),
    const _OnboardingPage(
      icon: '◫',
      title: 'Connect Your Services',
      description:
          'Link your Google account to manage calendar events and emails '
          'directly through conversation.',
    ),
  ];

  void _nextPage() {
    if (_currentPage < _pages.length) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _complete() async {
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your Claude API key')),
      );
      return;
    }

    await StorageService.instance.setApiKey(apiKey);
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NavixTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: List.generate(
                  _pages.length + 1,
                  (index) => Expanded(
                    child: Container(
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: index <= _currentPage
                            ? NavixTheme.primary
                            : NavixTheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                children: [
                  ..._pages,
                  _ApiKeyPage(controller: _apiKeyController),
                ],
              ),
            ),

            // Navigation buttons
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    TextButton(
                      onPressed: _previousPage,
                      child: const Text('Back'),
                    )
                  else
                    const SizedBox(width: 80),
                  const Spacer(),
                  if (_currentPage < _pages.length)
                    ElevatedButton(
                      onPressed: _nextPage,
                      child: const Text('Next'),
                    )
                  else
                    ElevatedButton(
                      onPressed: _complete,
                      child: const Text('Get Started'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }
}

class _OnboardingPage extends StatelessWidget {
  final String icon;
  final String title;
  final String description;

  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            icon,
            style: TextStyle(
              fontSize: 64,
              color: NavixTheme.primary,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            title,
            style: Theme.of(context).textTheme.displaySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: NavixTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ApiKeyPage extends StatelessWidget {
  final TextEditingController controller;

  const _ApiKeyPage({required this.controller});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '⊕',
            style: TextStyle(
              fontSize: 64,
              color: NavixTheme.primary,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Enter Your API Key',
            style: Theme.of(context).textTheme.displaySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'NavixMind uses Claude AI to understand your requests. '
            'Get your API key from console.anthropic.com',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: NavixTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'sk-ant-...',
              labelText: 'Claude API Key',
            ),
            obscureText: true,
          ),
          const SizedBox(height: 16),
          Text(
            'Your API key is stored securely on your device '
            'and never sent to our servers.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: NavixTheme.textTertiary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
