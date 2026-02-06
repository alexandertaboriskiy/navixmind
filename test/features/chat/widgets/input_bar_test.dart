import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navixmind/app/theme.dart';
import 'package:navixmind/features/chat/presentation/widgets/input_bar.dart';

void main() {
  group('InputBar', () {
    late TextEditingController controller;

    setUp(() {
      controller = TextEditingController();
    });

    tearDown(() {
      controller.dispose();
    });

    Widget createTestWidget({
      bool enabled = true,
      bool isProcessing = false,
      VoidCallback? onSend,
    }) {
      return MaterialApp(
        theme: NavixTheme.darkTheme,
        home: Scaffold(
          body: InputBar(
            controller: controller,
            onSend: onSend ?? () {},
            enabled: enabled,
            isProcessing: isProcessing,
          ),
        ),
      );
    }

    testWidgets('shows text field with hint', (tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Type a message...'), findsOneWidget);
    });

    testWidgets('shows add file button', (tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('shows send button when enabled', (tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
    });

    testWidgets('shows spinner when processing', (tester) async {
      await tester.pumpWidget(createTestWidget(isProcessing: true));

      // Send button should be replaced with spinner
      expect(find.byIcon(Icons.arrow_forward), findsNothing);
    });

    testWidgets('text field is disabled when not enabled', (tester) async {
      await tester.pumpWidget(createTestWidget(enabled: false));

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.enabled, isFalse);
    });

    testWidgets('calls onSend when send button is tapped', (tester) async {
      var sendCalled = false;
      await tester.pumpWidget(createTestWidget(
        onSend: () => sendCalled = true,
      ));

      // Enter text first
      await tester.enterText(find.byType(TextField), 'Hello');
      await tester.pump();

      // Tap send button
      await tester.tap(find.byIcon(Icons.arrow_forward));
      await tester.pump();

      expect(sendCalled, isTrue);
    });

    testWidgets('shows suggestions when typing /', (tester) async {
      await tester.pumpWidget(createTestWidget());

      await tester.enterText(find.byType(TextField), '/cr');
      await tester.pump();

      // Should show suggestion pills
      expect(find.text('/crop'), findsOneWidget);
    });
  });
}
