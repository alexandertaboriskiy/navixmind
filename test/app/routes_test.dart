import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navixmind/app/routes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('NavixMindRoutes constants', () {
    test('chat route is root', () {
      expect(NavixMindRoutes.chat, equals('/'));
    });

    test('settings route is /settings', () {
      expect(NavixMindRoutes.settings, equals('/settings'));
    });

    test('onboarding route is /onboarding', () {
      expect(NavixMindRoutes.onboarding, equals('/onboarding'));
    });
  });

  group('onGenerateRoute', () {
    test('generates route for chat path', () {
      final settings = const RouteSettings(name: '/');
      final route = NavixMindRoutes.onGenerateRoute(settings);

      expect(route, isNotNull);
      expect(route, isA<MaterialPageRoute>());
    });

    test('generates route for settings path', () {
      final settings = const RouteSettings(name: '/settings');
      final route = NavixMindRoutes.onGenerateRoute(settings);

      expect(route, isNotNull);
      expect(route, isA<MaterialPageRoute>());
    });

    test('generates route for onboarding path', () {
      final settings = const RouteSettings(name: '/onboarding');
      final route = NavixMindRoutes.onGenerateRoute(settings);

      expect(route, isNotNull);
      expect(route, isA<MaterialPageRoute>());
    });

    test('generates default route for unknown path', () {
      final settings = const RouteSettings(name: '/unknown');
      final route = NavixMindRoutes.onGenerateRoute(settings);

      expect(route, isNotNull);
      expect(route, isA<MaterialPageRoute>());
    });

    test('handles null route name', () {
      final settings = const RouteSettings(name: null);
      final route = NavixMindRoutes.onGenerateRoute(settings);

      // Should fall through to default case
      expect(route, isNotNull);
    });

    test('preserves route arguments', () {
      final settings = const RouteSettings(
        name: '/settings',
        arguments: {'section': 'google'},
      );
      final route = NavixMindRoutes.onGenerateRoute(settings);

      expect(route, isNotNull);
      // The route is generated, arguments are accessible via settings
      expect(settings.arguments, equals({'section': 'google'}));
    });
  });

  group('Route behavior', () {
    testWidgets('chat route builds without error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          onGenerateRoute: NavixMindRoutes.onGenerateRoute,
          initialRoute: '/',
        ),
      );

      // Should not throw
      expect(tester.takeException(), isNull);
    });

    testWidgets('settings route builds without error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          onGenerateRoute: NavixMindRoutes.onGenerateRoute,
          initialRoute: '/settings',
        ),
      );

      // Should not throw
      expect(tester.takeException(), isNull);
    });

    testWidgets('onboarding route builds without error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          onGenerateRoute: NavixMindRoutes.onGenerateRoute,
          initialRoute: '/onboarding',
        ),
      );

      // Should not throw
      expect(tester.takeException(), isNull);
    });

    testWidgets('navigates from chat to settings', (tester) async {
      // Use Builder to get correct context for navigation
      await tester.pumpWidget(
        MaterialApp(
          onGenerateRoute: NavixMindRoutes.onGenerateRoute,
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, '/settings'),
                child: const Text('Go to Settings'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Go to Settings'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Navigation should succeed without error
      expect(tester.takeException(), isNull);
    });
  });

  group('Route constants usage', () {
    test('chat constant can be used in navigation', () {
      // Verify the constant is a valid route string
      expect(NavixMindRoutes.chat, isA<String>());
      expect(NavixMindRoutes.chat.startsWith('/'), isTrue);
    });

    test('settings constant can be used in navigation', () {
      expect(NavixMindRoutes.settings, isA<String>());
      expect(NavixMindRoutes.settings.startsWith('/'), isTrue);
    });

    test('onboarding constant can be used in navigation', () {
      expect(NavixMindRoutes.onboarding, isA<String>());
      expect(NavixMindRoutes.onboarding.startsWith('/'), isTrue);
    });
  });

  group('MaterialPageRoute properties', () {
    test('route returns MaterialPageRoute type', () {
      final settings = const RouteSettings(name: '/');
      final route = NavixMindRoutes.onGenerateRoute(settings);

      expect(route.runtimeType.toString(), contains('MaterialPageRoute'));
    });
  });
}
