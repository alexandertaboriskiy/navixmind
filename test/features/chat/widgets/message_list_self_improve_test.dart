import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:navixmind/features/chat/presentation/chat_screen.dart';
import 'package:navixmind/features/chat/presentation/widgets/message_list.dart';

void main() {
  Widget buildTestApp({
    required List<ChatMessage> messages,
    bool selfImproveEnabled = false,
    bool isProcessing = false,
    void Function(int)? onSelfImprove,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: MessageList(
          messages: messages,
          scrollController: ScrollController(),
          selfImproveEnabled: selfImproveEnabled,
          isProcessing: isProcessing,
          onSelfImprove: onSelfImprove,
        ),
      ),
    );
  }

  group('MessageList Self Improve Button', () {
    testWidgets('button not shown when selfImproveEnabled is false', (tester) async {
      await tester.pumpWidget(buildTestApp(
        messages: [
          ChatMessage(
            role: MessageRole.assistant,
            content: 'Hello!',
            timestamp: DateTime.now(),
          ),
        ],
        selfImproveEnabled: false,
      ));

      expect(find.text('Self Improve'), findsNothing);
    });

    testWidgets('button shown below assistant message when enabled', (tester) async {
      await tester.pumpWidget(buildTestApp(
        messages: [
          ChatMessage(
            role: MessageRole.assistant,
            content: 'Hello!',
            timestamp: DateTime.now(),
          ),
        ],
        selfImproveEnabled: true,
      ));

      expect(find.text('Self Improve'), findsOneWidget);
    });

    testWidgets('button NOT shown for user messages', (tester) async {
      await tester.pumpWidget(buildTestApp(
        messages: [
          ChatMessage(
            role: MessageRole.user,
            content: 'Hi there',
            timestamp: DateTime.now(),
          ),
        ],
        selfImproveEnabled: true,
      ));

      expect(find.text('Self Improve'), findsNothing);
    });

    testWidgets('button NOT shown for system messages', (tester) async {
      await tester.pumpWidget(buildTestApp(
        messages: [
          ChatMessage(
            role: MessageRole.system,
            content: 'System message',
            timestamp: DateTime.now(),
          ),
        ],
        selfImproveEnabled: true,
      ));

      expect(find.text('Self Improve'), findsNothing);
    });

    testWidgets('button NOT shown for error messages', (tester) async {
      await tester.pumpWidget(buildTestApp(
        messages: [
          ChatMessage(
            role: MessageRole.error,
            content: 'Error occurred',
            timestamp: DateTime.now(),
          ),
        ],
        selfImproveEnabled: true,
      ));

      expect(find.text('Self Improve'), findsNothing);
    });

    testWidgets('button NOT shown when processing', (tester) async {
      await tester.pumpWidget(buildTestApp(
        messages: [
          ChatMessage(
            role: MessageRole.assistant,
            content: 'Hello!',
            timestamp: DateTime.now(),
          ),
        ],
        selfImproveEnabled: true,
        isProcessing: true,
      ));

      expect(find.text('Self Improve'), findsNothing);
    });

    testWidgets('multiple assistant messages show multiple buttons', (tester) async {
      await tester.pumpWidget(buildTestApp(
        messages: [
          ChatMessage(
            role: MessageRole.user,
            content: 'Question 1',
            timestamp: DateTime.now(),
          ),
          ChatMessage(
            role: MessageRole.assistant,
            content: 'Answer 1',
            timestamp: DateTime.now(),
          ),
          ChatMessage(
            role: MessageRole.user,
            content: 'Question 2',
            timestamp: DateTime.now(),
          ),
          ChatMessage(
            role: MessageRole.assistant,
            content: 'Answer 2',
            timestamp: DateTime.now(),
          ),
        ],
        selfImproveEnabled: true,
      ));

      expect(find.text('Self Improve'), findsNWidgets(2));
    });

    testWidgets('tapping button calls onSelfImprove with correct index', (tester) async {
      int? calledIndex;

      await tester.pumpWidget(buildTestApp(
        messages: [
          ChatMessage(
            role: MessageRole.user,
            content: 'Question',
            timestamp: DateTime.now(),
          ),
          ChatMessage(
            role: MessageRole.assistant,
            content: 'Answer',
            timestamp: DateTime.now(),
          ),
        ],
        selfImproveEnabled: true,
        onSelfImprove: (index) => calledIndex = index,
      ));

      await tester.tap(find.text('Self Improve'));
      await tester.pump();

      expect(calledIndex, equals(1)); // The assistant message is at index 1
    });

    testWidgets('mixed messages: only assistant messages get buttons', (tester) async {
      await tester.pumpWidget(buildTestApp(
        messages: [
          ChatMessage(
            role: MessageRole.system,
            content: 'Welcome',
            timestamp: DateTime.now(),
          ),
          ChatMessage(
            role: MessageRole.user,
            content: 'Hi',
            timestamp: DateTime.now(),
          ),
          ChatMessage(
            role: MessageRole.assistant,
            content: 'Hello!',
            timestamp: DateTime.now(),
          ),
          ChatMessage(
            role: MessageRole.error,
            content: 'Error',
            timestamp: DateTime.now(),
          ),
          ChatMessage(
            role: MessageRole.assistant,
            content: 'Recovered',
            timestamp: DateTime.now(),
          ),
        ],
        selfImproveEnabled: true,
      ));

      // Only 2 assistant messages should have buttons
      expect(find.text('Self Improve'), findsNWidgets(2));
    });

    testWidgets('button is a TextButton.icon', (tester) async {
      await tester.pumpWidget(buildTestApp(
        messages: [
          ChatMessage(
            role: MessageRole.assistant,
            content: 'Hello!',
            timestamp: DateTime.now(),
          ),
        ],
        selfImproveEnabled: true,
      ));

      // The button text should be present
      expect(find.text('Self Improve'), findsOneWidget);
      // And the icon character
      expect(find.text('✦'), findsOneWidget);
    });

    testWidgets('empty messages show empty state, no buttons', (tester) async {
      await tester.pumpWidget(buildTestApp(
        messages: [],
        selfImproveEnabled: true,
      ));

      expect(find.text('Self Improve'), findsNothing);
      expect(find.text('Start a conversation'), findsOneWidget);
    });
  });
}
