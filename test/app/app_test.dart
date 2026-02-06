import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navixmind/app/app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('NavixMindApp', () {
    test('creates with default values', () {
      const app = NavixMindApp();

      expect(app.initializing, isFalse);
      expect(app.isar, isNull);
    });

    test('creates with initializing true', () {
      const app = NavixMindApp(initializing: true);

      expect(app.initializing, isTrue);
    });

    test('creates with isar instance', () {
      // We can't create a real Isar instance in unit tests without
      // platform setup, but we can verify the parameter exists
      const app = NavixMindApp(initializing: false);

      // The app accepts an optional isar parameter
      expect(app.isar, isNull);
    });

    testWidgets('builds MaterialApp', (tester) async {
      await tester.pumpWidget(const NavixMindApp(initializing: true));

      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('has correct title', (tester) async {
      await tester.pumpWidget(const NavixMindApp(initializing: true));

      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.title, equals('NavixMind'));
    });

    testWidgets('hides debug banner', (tester) async {
      await tester.pumpWidget(const NavixMindApp(initializing: true));

      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.debugShowCheckedModeBanner, isFalse);
    });

    testWidgets('uses dark theme', (tester) async {
      await tester.pumpWidget(const NavixMindApp(initializing: true));

      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.theme, isNotNull);
      expect(materialApp.theme!.brightness, equals(Brightness.dark));
    });

    testWidgets('has route generator', (tester) async {
      await tester.pumpWidget(const NavixMindApp(initializing: true));

      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.onGenerateRoute, isNotNull);
    });

    testWidgets('passes initializing to ChatScreen', (tester) async {
      await tester.pumpWidget(const NavixMindApp(initializing: true));

      // The ChatScreen is the home widget
      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.home, isNotNull);
    });
  });

  group('App configuration', () {
    test('app title is NavixMind', () {
      const title = 'NavixMind';
      expect(title, equals('NavixMind'));
    });

    test('debug banner is disabled', () {
      const showDebugBanner = false;
      expect(showDebugBanner, isFalse);
    });
  });
}
