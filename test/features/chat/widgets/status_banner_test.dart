import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navixmind/app/theme.dart';
import 'package:navixmind/features/chat/presentation/widgets/status_banner.dart';
import 'package:navixmind/shared/widgets/spinner.dart';

void main() {
  group('StatusBanner', () {
    Widget createTestWidget({
      required String message,
      bool isError = false,
      VoidCallback? onRetry,
    }) {
      return MaterialApp(
        theme: NavixTheme.darkTheme,
        home: Scaffold(
          body: StatusBanner(
            message: message,
            isError: isError,
            onRetry: onRetry,
          ),
        ),
      );
    }

    group('Normal status', () {
      testWidgets('displays message', (tester) async {
        await tester.pumpWidget(createTestWidget(
          message: 'Connecting...',
        ));

        expect(find.text('Connecting...'), findsOneWidget);
      });

      testWidgets('shows spinner when not error', (tester) async {
        await tester.pumpWidget(createTestWidget(
          message: 'Loading...',
          isError: false,
        ));

        expect(find.byType(BrailleSpinner), findsOneWidget);
      });

      testWidgets('does not show warning icon when not error', (tester) async {
        await tester.pumpWidget(createTestWidget(
          message: 'Loading...',
          isError: false,
        ));

        expect(find.text(NavixTheme.iconWarning), findsNothing);
      });

      testWidgets('does not show retry button when not error', (tester) async {
        await tester.pumpWidget(createTestWidget(
          message: 'Loading...',
          isError: false,
          onRetry: () {},
        ));

        expect(find.text('Retry'), findsNothing);
      });

      testWidgets('uses surface background color', (tester) async {
        await tester.pumpWidget(createTestWidget(
          message: 'Normal status',
          isError: false,
        ));

        final container = tester.widget<Container>(find.byType(Container).first);
        expect(container.color, equals(NavixTheme.surface));
      });

      testWidgets('message has secondary text color', (tester) async {
        await tester.pumpWidget(createTestWidget(
          message: 'Status message',
          isError: false,
        ));

        final messageText = tester.widget<Text>(find.text('Status message'));
        expect(messageText.style?.color, equals(NavixTheme.textSecondary));
      });
    });

    group('Error status', () {
      testWidgets('displays error message', (tester) async {
        await tester.pumpWidget(createTestWidget(
          message: 'Connection failed',
          isError: true,
        ));

        expect(find.text('Connection failed'), findsOneWidget);
      });

      testWidgets('shows warning icon instead of spinner', (tester) async {
        await tester.pumpWidget(createTestWidget(
          message: 'Error',
          isError: true,
        ));

        expect(find.text(NavixTheme.iconWarning), findsOneWidget);
        expect(find.byType(BrailleSpinner), findsNothing);
      });

      testWidgets('shows retry button when onRetry provided', (tester) async {
        await tester.pumpWidget(createTestWidget(
          message: 'Error',
          isError: true,
          onRetry: () {},
        ));

        expect(find.text('Retry'), findsOneWidget);
      });

      testWidgets('hides retry button when onRetry not provided', (tester) async {
        await tester.pumpWidget(createTestWidget(
          message: 'Error',
          isError: true,
          onRetry: null,
        ));

        expect(find.text('Retry'), findsNothing);
      });

      testWidgets('calls onRetry when retry button tapped', (tester) async {
        var retryCalled = false;
        await tester.pumpWidget(createTestWidget(
          message: 'Error',
          isError: true,
          onRetry: () => retryCalled = true,
        ));

        await tester.tap(find.text('Retry'));
        await tester.pump();

        expect(retryCalled, isTrue);
      });

      testWidgets('uses error background color', (tester) async {
        await tester.pumpWidget(createTestWidget(
          message: 'Error status',
          isError: true,
        ));

        final container = tester.widget<Container>(find.byType(Container).first);
        final expectedColor = NavixTheme.error.withOpacity(0.15);
        expect(container.color, equals(expectedColor));
      });

      testWidgets('message has error text color', (tester) async {
        await tester.pumpWidget(createTestWidget(
          message: 'Error message',
          isError: true,
        ));

        final messageText = tester.widget<Text>(find.text('Error message'));
        expect(messageText.style?.color, equals(NavixTheme.error));
      });

      testWidgets('warning icon has error color', (tester) async {
        await tester.pumpWidget(createTestWidget(
          message: 'Error',
          isError: true,
        ));

        final warningIcon = tester.widget<Text>(
          find.text(NavixTheme.iconWarning),
        );
        expect(warningIcon.style?.color, equals(NavixTheme.error));
      });
    });

    group('Layout', () {
      testWidgets('spans full width', (tester) async {
        await tester.pumpWidget(createTestWidget(
          message: 'Test',
        ));

        // The banner should take full width (unconstrained = infinity, or no constraint)
        final container = tester.widget<Container>(find.byType(Container).first);
        // Either constraints is null, or maxWidth is infinity (both mean unconstrained)
        expect(
          container.constraints == null ||
              container.constraints!.maxWidth == double.infinity,
          isTrue,
        );
      });

      testWidgets('message expands to fill available space', (tester) async {
        await tester.pumpWidget(createTestWidget(
          message: 'Expandable message',
        ));

        expect(find.byType(Expanded), findsOneWidget);
      });

      testWidgets('has correct padding', (tester) async {
        await tester.pumpWidget(createTestWidget(
          message: 'Test',
        ));

        final container = tester.widget<Container>(find.byType(Container).first);
        expect(
          container.padding,
          equals(const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
        );
      });
    });

    group('Different messages', () {
      testWidgets('displays connecting message', (tester) async {
        await tester.pumpWidget(createTestWidget(
          message: 'Connecting to server...',
        ));
        expect(find.text('Connecting to server...'), findsOneWidget);
      });

      testWidgets('displays initializing message', (tester) async {
        await tester.pumpWidget(createTestWidget(
          message: 'Initializing AI model...',
        ));
        expect(find.text('Initializing AI model...'), findsOneWidget);
      });

      testWidgets('displays processing message', (tester) async {
        await tester.pumpWidget(createTestWidget(
          message: 'Processing your request...',
        ));
        expect(find.text('Processing your request...'), findsOneWidget);
      });

      testWidgets('displays offline error', (tester) async {
        await tester.pumpWidget(createTestWidget(
          message: 'No internet connection',
          isError: true,
          onRetry: () {},
        ));
        expect(find.text('No internet connection'), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
      });

      testWidgets('displays API error', (tester) async {
        await tester.pumpWidget(createTestWidget(
          message: 'API request failed. Please try again.',
          isError: true,
          onRetry: () {},
        ));
        expect(find.text('API request failed. Please try again.'), findsOneWidget);
      });
    });

    group('Edge cases', () {
      testWidgets('handles empty message', (tester) async {
        await tester.pumpWidget(createTestWidget(
          message: '',
        ));
        expect(find.text(''), findsOneWidget);
      });

      testWidgets('handles very long message', (tester) async {
        final longMessage = 'A' * 200;
        await tester.pumpWidget(createTestWidget(
          message: longMessage,
        ));
        expect(find.text(longMessage), findsOneWidget);
      });

      testWidgets('handles message with special characters', (tester) async {
        await tester.pumpWidget(createTestWidget(
          message: 'Error: 404 - Not Found! @#\$%',
        ));
        expect(find.text('Error: 404 - Not Found! @#\$%'), findsOneWidget);
      });
    });
  });
}
