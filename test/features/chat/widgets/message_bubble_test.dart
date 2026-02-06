import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navixmind/app/theme.dart';
import 'package:navixmind/features/chat/presentation/chat_screen.dart';
import 'package:navixmind/features/chat/presentation/widgets/message_bubble.dart';

void main() {
  group('MessageBubble', () {
    Widget createTestWidget(ChatMessage message) {
      return MaterialApp(
        theme: NavixTheme.darkTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: MessageBubble(message: message),
          ),
        ),
      );
    }

    group('User messages', () {
      testWidgets('displays user message content', (tester) async {
        final message = ChatMessage(
          role: MessageRole.user,
          content: 'Hello, world!',
          timestamp: DateTime.now(),
        );

        await tester.pumpWidget(createTestWidget(message));

        expect(find.text('Hello, world!'), findsOneWidget);
      });

      testWidgets('user messages align to the right', (tester) async {
        final message = ChatMessage(
          role: MessageRole.user,
          content: 'Test message',
          timestamp: DateTime.now(),
        );

        await tester.pumpWidget(createTestWidget(message));

        final row = tester.widget<Row>(find.byType(Row).first);
        expect(row.mainAxisAlignment, equals(MainAxisAlignment.end));
      });

      testWidgets('user messages show role indicator on right', (tester) async {
        final message = ChatMessage(
          role: MessageRole.user,
          content: 'Test',
          timestamp: DateTime.now(),
        );

        await tester.pumpWidget(createTestWidget(message));

        // User role indicator should be present (circle with ●)
        expect(find.text('●'), findsOneWidget);
      });
    });

    group('Assistant messages', () {
      testWidgets('displays assistant message content', (tester) async {
        final message = ChatMessage(
          role: MessageRole.assistant,
          content: 'I can help you with that!',
          timestamp: DateTime.now(),
        );

        await tester.pumpWidget(createTestWidget(message));

        expect(find.text('I can help you with that!'), findsOneWidget);
      });

      testWidgets('assistant messages align to the left', (tester) async {
        final message = ChatMessage(
          role: MessageRole.assistant,
          content: 'Test response',
          timestamp: DateTime.now(),
        );

        await tester.pumpWidget(createTestWidget(message));

        final row = tester.widget<Row>(find.byType(Row).first);
        expect(row.mainAxisAlignment, equals(MainAxisAlignment.start));
      });

      testWidgets('assistant messages show role indicator on left', (tester) async {
        final message = ChatMessage(
          role: MessageRole.assistant,
          content: 'Test',
          timestamp: DateTime.now(),
        );

        await tester.pumpWidget(createTestWidget(message));

        // Assistant role indicator (◆)
        expect(find.text('◆'), findsOneWidget);
      });
    });

    group('Error messages', () {
      testWidgets('displays error message with warning icon', (tester) async {
        final message = ChatMessage(
          role: MessageRole.error,
          content: 'Something went wrong',
          timestamp: DateTime.now(),
        );

        await tester.pumpWidget(createTestWidget(message));

        expect(find.text('Something went wrong'), findsOneWidget);
        // Warning icon
        expect(find.text(NavixTheme.iconWarning), findsOneWidget);
      });

      testWidgets('error messages have error styling', (tester) async {
        final message = ChatMessage(
          role: MessageRole.error,
          content: 'Error!',
          timestamp: DateTime.now(),
        );

        await tester.pumpWidget(createTestWidget(message));

        // Should find Container with error background
        final container = tester.widget<Container>(
          find.ancestor(
            of: find.text('Error!'),
            matching: find.byType(Container),
          ).first,
        );
        expect(container.decoration, isNotNull);
      });
    });

    group('System messages', () {
      testWidgets('displays system message', (tester) async {
        final message = ChatMessage(
          role: MessageRole.system,
          content: 'System notification',
          timestamp: DateTime.now(),
        );

        await tester.pumpWidget(createTestWidget(message));

        expect(find.text('System notification'), findsOneWidget);
      });

      testWidgets('system messages align to the left', (tester) async {
        final message = ChatMessage(
          role: MessageRole.system,
          content: 'System',
          timestamp: DateTime.now(),
        );

        await tester.pumpWidget(createTestWidget(message));

        final row = tester.widget<Row>(find.byType(Row).first);
        expect(row.mainAxisAlignment, equals(MainAxisAlignment.start));
      });
    });

    group('Code blocks', () {
      testWidgets('renders code blocks correctly', (tester) async {
        final message = ChatMessage(
          role: MessageRole.assistant,
          content: 'Here is code:\n```python\nprint("Hello")\n```',
          timestamp: DateTime.now(),
        );

        await tester.pumpWidget(createTestWidget(message));

        expect(find.text('python'), findsOneWidget);
        expect(find.text('print("Hello")'), findsOneWidget);
      });

      testWidgets('handles code blocks without language', (tester) async {
        final message = ChatMessage(
          role: MessageRole.assistant,
          content: 'Code:\n```\nsome code\n```',
          timestamp: DateTime.now(),
        );

        await tester.pumpWidget(createTestWidget(message));

        expect(find.text('some code'), findsOneWidget);
      });

      testWidgets('handles multiple code blocks', (tester) async {
        final message = ChatMessage(
          role: MessageRole.assistant,
          content: '''First:
```python
code1
```

Second:
```javascript
code2
```''',
          timestamp: DateTime.now(),
        );

        await tester.pumpWidget(createTestWidget(message));

        expect(find.text('python'), findsOneWidget);
        expect(find.text('javascript'), findsOneWidget);
        expect(find.text('code1'), findsOneWidget);
        expect(find.text('code2'), findsOneWidget);
      });

      testWidgets('handles text before and after code blocks', (tester) async {
        final message = ChatMessage(
          role: MessageRole.assistant,
          content: 'Before code\n```\ncode\n```\nAfter code',
          timestamp: DateTime.now(),
        );

        await tester.pumpWidget(createTestWidget(message));

        expect(find.text('Before code'), findsOneWidget);
        expect(find.text('After code'), findsOneWidget);
      });
    });

    group('Accessibility', () {
      testWidgets('user message has correct accessibility label', (tester) async {
        final message = ChatMessage(
          role: MessageRole.user,
          content: 'Test accessibility',
          timestamp: DateTime.now(),
        );

        await tester.pumpWidget(createTestWidget(message));

        final semantics = tester.getSemantics(find.byType(MessageBubble));
        expect(semantics.label, contains('You said'));
        expect(semantics.label, contains('Test accessibility'));
      });

      testWidgets('assistant message has correct accessibility label', (tester) async {
        final message = ChatMessage(
          role: MessageRole.assistant,
          content: 'AI response',
          timestamp: DateTime.now(),
        );

        await tester.pumpWidget(createTestWidget(message));

        final semantics = tester.getSemantics(find.byType(MessageBubble));
        expect(semantics.label, contains('NavixMind replied'));
      });

      testWidgets('has long press hint for copy', (tester) async {
        final message = ChatMessage(
          role: MessageRole.user,
          content: 'Copy me',
          timestamp: DateTime.now(),
        );

        await tester.pumpWidget(createTestWidget(message));

        final semantics = tester.getSemantics(find.byType(MessageBubble));
        expect(semantics.hint, contains('Long press to copy'));
      });
    });

    group('Context menu', () {
      testWidgets('long press shows context menu', (tester) async {
        final message = ChatMessage(
          role: MessageRole.user,
          content: 'Long press me',
          timestamp: DateTime.now(),
        );

        await tester.pumpWidget(createTestWidget(message));

        // Find and long press the message content text directly
        // The GestureDetector wraps the Row, so we can target the text
        final messageText = find.text('Long press me');
        expect(messageText, findsOneWidget);

        // Use TestGesture for more control over the long press
        final center = tester.getCenter(messageText);
        final gesture = await tester.startGesture(center);
        await tester.pump(const Duration(milliseconds: 600)); // Long press duration
        await gesture.up();
        await tester.pumpAndSettle();

        // Should show bottom sheet with Copy option
        expect(find.text('Copy'), findsOneWidget);
      });

      testWidgets('copy option dismisses menu when tapped', (tester) async {
        final message = ChatMessage(
          role: MessageRole.user,
          content: 'Copy this text',
          timestamp: DateTime.now(),
        );

        await tester.pumpWidget(createTestWidget(message));

        // Find and long press the message content text
        final messageText = find.text('Copy this text');
        final center = tester.getCenter(messageText);
        final gesture = await tester.startGesture(center);
        await tester.pump(const Duration(milliseconds: 600));
        await gesture.up();
        await tester.pumpAndSettle();

        // Verify Copy option appears in the modal
        expect(find.text('Copy'), findsOneWidget);

        // Tap Copy option
        await tester.tap(find.text('Copy'));
        await tester.pumpAndSettle();

        // Modal should be dismissed (Copy text no longer visible)
        expect(find.text('Copy'), findsNothing);
      });
    });

    group('Text selection', () {
      testWidgets('message content is selectable', (tester) async {
        final message = ChatMessage(
          role: MessageRole.assistant,
          content: 'Select me',
          timestamp: DateTime.now(),
        );

        await tester.pumpWidget(createTestWidget(message));

        expect(find.byType(SelectableText), findsAtLeastNWidgets(1));
      });
    });

    group('Layout constraints', () {
      testWidgets('message bubble respects max width', (tester) async {
        final message = ChatMessage(
          role: MessageRole.assistant,
          content: 'A' * 500, // Long message
          timestamp: DateTime.now(),
        );

        await tester.pumpWidget(createTestWidget(message));

        // Get screen width
        final screenWidth = tester.getSize(find.byType(Scaffold)).width;

        // Find the message content container - it should be constrained
        // Look for Container widgets that have BoxConstraints
        final containers = tester.widgetList<Container>(find.byType(Container));

        // Find a container with maxWidth constraint (the message bubble)
        Container? constrainedContainer;
        for (final container in containers) {
          if (container.constraints?.maxWidth != null &&
              container.constraints!.maxWidth < double.infinity) {
            constrainedContainer = container;
            break;
          }
        }

        expect(constrainedContainer, isNotNull);
        expect(constrainedContainer!.constraints!.maxWidth, lessThan(screenWidth));
      });
    });
  });

  group('ChatMessage', () {
    test('creates message with required fields', () {
      final message = ChatMessage(
        role: MessageRole.user,
        content: 'Test',
        timestamp: DateTime(2024, 1, 1, 12, 0),
      );

      expect(message.role, equals(MessageRole.user));
      expect(message.content, equals('Test'));
      expect(message.timestamp.hour, equals(12));
    });
  });

  group('MessageRole', () {
    test('has all expected roles', () {
      expect(MessageRole.values, contains(MessageRole.user));
      expect(MessageRole.values, contains(MessageRole.assistant));
      expect(MessageRole.values, contains(MessageRole.system));
      expect(MessageRole.values, contains(MessageRole.error));
    });
  });
}
