import 'package:flutter/material.dart';

import '../features/chat/presentation/chat_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/onboarding/onboarding_screen.dart';

class NavixMindRoutes {
  static const String chat = '/';
  static const String settings = '/settings';
  static const String onboarding = '/onboarding';

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case chat:
        return MaterialPageRoute(
          builder: (_) => const ChatScreen(),
        );
      case NavixMindRoutes.settings:
        return MaterialPageRoute(
          builder: (_) => const SettingsScreen(),
        );
      case onboarding:
        return MaterialPageRoute(
          builder: (_) => const OnboardingScreen(),
        );
      default:
        return MaterialPageRoute(
          builder: (_) => const ChatScreen(),
        );
    }
  }
}
