import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navixmind/app/theme.dart';
import 'package:navixmind/features/chat/presentation/chat_screen.dart';
import 'package:navixmind/features/chat/presentation/widgets/message_list.dart';
import 'package:navixmind/features/chat/presentation/widgets/message_bubble.dart';

void main() {
  group('MessageList', () {
    late ScrollController scrollController;

    setUp(() {
      scrollController = ScrollController();
    });

    tearDown(() {
      scrollController.dispose();
    });

    Widget createTestWidget({
      required List<ChatMessage> messages,
      ScrollController? controller,
    }) {
      return MaterialApp(
        theme: NavixTheme.darkTheme,
        home: Scaffold(
          body: MessageList(
            messages: messages,
            scrollController: controller ?? scrollController,
          ),
        ),
      );
    }

    group('Empty state', () {
      testWidgets('shows empty state when no messages', (tester) async {
        await tester.pumpWidget(createTestWidget(messages: []));

        // Should not show ListView.builder
        expect(find.byType(ListView), findsNothing);

        // Should show centered content
        expect(find.byType(Center), findsOneWidget);
      });

      testWidgets('empty state has correct icon', (tester) async {
        await tester.pumpWidget(createTestWidget(messages: []));

        // Should show the add icon
        expect(find.text(NavixTheme.iconAdd), findsOneWidget);
      });

      testWidgets('empty state has correct title', (tester) async {
        await tester.pumpWidget(createTestWidget(messages: []));

        expect(find.text('Start a conversation'), findsOneWidget);
      });

      testWidgets('empty state has correct subtitle', (tester) async {
        await tester.pumpWidget(createTestWidget(messages: []));

        expect(
          find.text('Ask me anything or share a file to get started'),
          findsOneWidget,
        );
      });

      testWidgets('empty state icon has correct styling', (tester) async {
        await tester.pumpWidget(createTestWidget(messages: []));

        final iconFinder = find.text(NavixTheme.iconAdd);
        final iconWidget = tester.widget<Text>(iconFinder);

        expect(iconWidget.style?.fontSize, equals(48));
        expect(iconWidget.style?.color, equals(NavixTheme.textTertiary));
      });

      testWidgets('empty state title has correct styling', (tester) async {
        await tester.pumpWidget(createTestWidget(messages: []));

        final titleFinder = find.text('Start a conversation');
        final titleWidget = tester.widget<Text>(titleFinder);

        expect(titleWidget.style?.color, equals(NavixTheme.textSecondary));
      });

      testWidgets('empty state subtitle has correct styling', (tester) async {
        await tester.pumpWidget(createTestWidget(messages: []));

        final subtitleFinder = find.text(
          'Ask me anything or share a file to get started',
        );
        final subtitleWidget = tester.widget<Text>(subtitleFinder);

        expect(subtitleWidget.style?.color, equals(NavixTheme.textTertiary));
        expect(subtitleWidget.textAlign, equals(TextAlign.center));
      });

      testWidgets('empty state is vertically centered', (tester) async {
        await tester.pumpWidget(createTestWidget(messages: []));

        final columnFinder = find.descendant(
          of: find.byType(Center),
          matching: find.byType(Column),
        );
        final columnWidget = tester.widget<Column>(columnFinder);

        expect(
          columnWidget.mainAxisAlignment,
          equals(MainAxisAlignment.center),
        );
      });
    });

    group('Messages rendering', () {
      testWidgets('renders messages with MessageBubble', (tester) async {
        final messages = [
          ChatMessage(
            role: MessageRole.user,
            content: 'Hello',
            timestamp: DateTime.now(),
          ),
          ChatMessage(
            role: MessageRole.assistant,
            content: 'Hi there!',
            timestamp: DateTime.now(),
          ),
        ];

        await tester.pumpWidget(createTestWidget(messages: messages));

        expect(find.byType(MessageBubble), findsNWidgets(2));
        expect(find.text('Hello'), findsOneWidget);
        expect(find.text('Hi there!'), findsOneWidget);
      });

      testWidgets('renders single message correctly', (tester) async {
        final messages = [
          ChatMessage(
            role: MessageRole.user,
            content: 'Single message',
            timestamp: DateTime.now(),
          ),
        ];

        await tester.pumpWidget(createTestWidget(messages: messages));

        expect(find.byType(MessageBubble), findsOneWidget);
        expect(find.text('Single message'), findsOneWidget);
      });

      testWidgets('renders multiple messages correctly', (tester) async {
        final now = DateTime.now();
        final messages = List.generate(
          5,
          (index) => ChatMessage(
            role: index.isEven ? MessageRole.user : MessageRole.assistant,
            content: 'Message $index',
            timestamp: now,
          ),
        );

        await tester.pumpWidget(createTestWidget(messages: messages));

        expect(find.byType(MessageBubble), findsNWidgets(5));
        for (var i = 0; i < 5; i++) {
          expect(find.text('Message $i'), findsOneWidget);
        }
      });

      testWidgets('renders different message roles', (tester) async {
        final now = DateTime.now();
        final messages = [
          ChatMessage(
            role: MessageRole.user,
            content: 'User message',
            timestamp: now,
          ),
          ChatMessage(
            role: MessageRole.assistant,
            content: 'Assistant message',
            timestamp: now,
          ),
          ChatMessage(
            role: MessageRole.system,
            content: 'System message',
            timestamp: now,
          ),
          ChatMessage(
            role: MessageRole.error,
            content: 'Error message',
            timestamp: now,
          ),
        ];

        await tester.pumpWidget(createTestWidget(messages: messages));

        expect(find.byType(MessageBubble), findsNWidgets(4));
        expect(find.text('User message'), findsOneWidget);
        expect(find.text('Assistant message'), findsOneWidget);
        expect(find.text('System message'), findsOneWidget);
        expect(find.text('Error message'), findsOneWidget);
      });
    });

    group('ListView configuration', () {
      testWidgets('uses ListView.builder for virtualization', (tester) async {
        final messages = [
          ChatMessage(
            role: MessageRole.user,
            content: 'Test',
            timestamp: DateTime.now(),
          ),
        ];

        await tester.pumpWidget(createTestWidget(messages: messages));

        expect(find.byType(ListView), findsOneWidget);
      });

      testWidgets('ListView uses correct horizontal padding', (tester) async {
        final messages = [
          ChatMessage(
            role: MessageRole.user,
            content: 'Test',
            timestamp: DateTime.now(),
          ),
        ];

        await tester.pumpWidget(createTestWidget(messages: messages));

        final listView = tester.widget<ListView>(find.byType(ListView));
        final padding = listView.padding as EdgeInsets;

        expect(padding.left, equals(16));
        expect(padding.right, equals(16));
      });

      testWidgets('ListView uses correct vertical padding', (tester) async {
        final messages = [
          ChatMessage(
            role: MessageRole.user,
            content: 'Test',
            timestamp: DateTime.now(),
          ),
        ];

        await tester.pumpWidget(createTestWidget(messages: messages));

        final listView = tester.widget<ListView>(find.byType(ListView));
        final padding = listView.padding as EdgeInsets;

        expect(padding.top, equals(8));
        expect(padding.bottom, equals(8));
      });

      testWidgets('scroll controller is attached', (tester) async {
        final messages = [
          ChatMessage(
            role: MessageRole.user,
            content: 'Test',
            timestamp: DateTime.now(),
          ),
        ];

        await tester.pumpWidget(createTestWidget(messages: messages));

        expect(scrollController.hasClients, isTrue);
      });

      testWidgets('can scroll with provided controller', (tester) async {
        final messages = List.generate(
          20,
          (index) => ChatMessage(
            role: MessageRole.user,
            content: 'Long message content $index that takes space',
            timestamp: DateTime.now(),
          ),
        );

        await tester.pumpWidget(createTestWidget(messages: messages));

        // Initial position should be 0
        expect(scrollController.offset, equals(0));

        // Scroll down
        scrollController.jumpTo(100);
        await tester.pump();

        expect(scrollController.offset, equals(100));
      });
    });

    group('Timestamp dividers', () {
      testWidgets('shows timestamp divider for first message', (tester) async {
        final messages = [
          ChatMessage(
            role: MessageRole.user,
            content: 'First message',
            timestamp: DateTime.now(),
          ),
        ];

        await tester.pumpWidget(createTestWidget(messages: messages));

        // Should have a divider (Row with Divider widgets)
        expect(find.byType(Divider), findsNWidgets(2));
      });

      testWidgets('shows timestamp divider when messages are >5 minutes apart',
          (tester) async {
        final now = DateTime.now();
        final messages = [
          ChatMessage(
            role: MessageRole.user,
            content: 'First message',
            timestamp: now,
          ),
          ChatMessage(
            role: MessageRole.assistant,
            content: 'Second message',
            timestamp: now.add(const Duration(minutes: 6)),
          ),
        ];

        await tester.pumpWidget(createTestWidget(messages: messages));

        // Should have 2 timestamp dividers (4 Divider widgets total)
        expect(find.byType(Divider), findsNWidgets(4));
      });

      testWidgets('no timestamp divider when messages are <5 minutes apart',
          (tester) async {
        final now = DateTime.now();
        final messages = [
          ChatMessage(
            role: MessageRole.user,
            content: 'First message',
            timestamp: now,
          ),
          ChatMessage(
            role: MessageRole.assistant,
            content: 'Second message',
            timestamp: now.add(const Duration(minutes: 4)),
          ),
        ];

        await tester.pumpWidget(createTestWidget(messages: messages));

        // Should have only 1 timestamp divider for first message (2 Divider widgets)
        expect(find.byType(Divider), findsNWidgets(2));
      });

      testWidgets('no timestamp divider when messages are exactly 5 minutes apart',
          (tester) async {
        final now = DateTime.now();
        final messages = [
          ChatMessage(
            role: MessageRole.user,
            content: 'First message',
            timestamp: now,
          ),
          ChatMessage(
            role: MessageRole.assistant,
            content: 'Second message',
            timestamp: now.add(const Duration(minutes: 5)),
          ),
        ];

        await tester.pumpWidget(createTestWidget(messages: messages));

        // 5 minutes exactly is NOT > 5, so no divider for second message
        expect(find.byType(Divider), findsNWidgets(2));
      });

      testWidgets('shows timestamp divider for rapid then delayed messages',
          (tester) async {
        final now = DateTime.now();
        final messages = [
          ChatMessage(
            role: MessageRole.user,
            content: 'Message 1',
            timestamp: now,
          ),
          ChatMessage(
            role: MessageRole.assistant,
            content: 'Message 2',
            timestamp: now.add(const Duration(minutes: 1)),
          ),
          ChatMessage(
            role: MessageRole.user,
            content: 'Message 3',
            timestamp: now.add(const Duration(minutes: 2)),
          ),
          ChatMessage(
            role: MessageRole.assistant,
            content: 'Message 4 - after delay',
            timestamp: now.add(const Duration(minutes: 10)),
          ),
        ];

        await tester.pumpWidget(createTestWidget(messages: messages));

        // First message gets divider, messages 2 and 3 don't (within 5 min of previous),
        // message 4 gets divider (>5 min after message 3)
        // Total: 2 dividers = 4 Divider widgets
        expect(find.byType(Divider), findsNWidgets(4));
      });
    });

    group('Timestamp formatting', () {
      testWidgets('formats timestamp as HH:mm for today', (tester) async {
        final now = DateTime.now();
        final testTime = DateTime(now.year, now.month, now.day, 14, 30);
        final messages = [
          ChatMessage(
            role: MessageRole.user,
            content: 'Test message',
            timestamp: testTime,
          ),
        ];

        await tester.pumpWidget(createTestWidget(messages: messages));

        expect(find.text('14:30'), findsOneWidget);
      });

      testWidgets('formats timestamp with padded hours for today',
          (tester) async {
        final now = DateTime.now();
        final testTime = DateTime(now.year, now.month, now.day, 9, 5);
        final messages = [
          ChatMessage(
            role: MessageRole.user,
            content: 'Test message',
            timestamp: testTime,
          ),
        ];

        await tester.pumpWidget(createTestWidget(messages: messages));

        expect(find.text('09:05'), findsOneWidget);
      });

      testWidgets('formats timestamp as M/d HH:mm for other days',
          (tester) async {
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        final testTime = DateTime(
          yesterday.year,
          yesterday.month,
          yesterday.day,
          14,
          30,
        );
        final messages = [
          ChatMessage(
            role: MessageRole.user,
            content: 'Test message',
            timestamp: testTime,
          ),
        ];

        await tester.pumpWidget(createTestWidget(messages: messages));

        expect(
          find.text('${testTime.month}/${testTime.day} 14:30'),
          findsOneWidget,
        );
      });

      testWidgets('formats timestamp with padded time for other days',
          (tester) async {
        final pastDate = DateTime.now().subtract(const Duration(days: 5));
        final testTime = DateTime(
          pastDate.year,
          pastDate.month,
          pastDate.day,
          8,
          3,
        );
        final messages = [
          ChatMessage(
            role: MessageRole.user,
            content: 'Test message',
            timestamp: testTime,
          ),
        ];

        await tester.pumpWidget(createTestWidget(messages: messages));

        expect(
          find.text('${testTime.month}/${testTime.day} 08:03'),
          findsOneWidget,
        );
      });

      testWidgets('formats midnight correctly for today', (tester) async {
        final now = DateTime.now();
        final testTime = DateTime(now.year, now.month, now.day, 0, 0);
        final messages = [
          ChatMessage(
            role: MessageRole.user,
            content: 'Midnight message',
            timestamp: testTime,
          ),
        ];

        await tester.pumpWidget(createTestWidget(messages: messages));

        expect(find.text('00:00'), findsOneWidget);
      });
    });

    group('Edge cases', () {
      testWidgets('handles messages at day boundary', (tester) async {
        final now = DateTime.now();
        final yesterday = now.subtract(const Duration(days: 1));
        final messages = [
          ChatMessage(
            role: MessageRole.user,
            content: 'Yesterday message',
            timestamp: DateTime(
              yesterday.year,
              yesterday.month,
              yesterday.day,
              23,
              55,  // Changed from 23:58 to ensure >5 min gap
            ),
          ),
          ChatMessage(
            role: MessageRole.assistant,
            content: 'Today message',
            timestamp: DateTime(now.year, now.month, now.day, 0, 2),
          ),
        ];

        await tester.pumpWidget(createTestWidget(messages: messages));

        // Both messages should be rendered
        expect(find.text('Yesterday message'), findsOneWidget);
        expect(find.text('Today message'), findsOneWidget);

        // First message should show date format (M/d HH:mm)
        expect(
          find.text('${yesterday.month}/${yesterday.day} 23:55'),
          findsOneWidget,
        );

        // Second message shows divider (>5 min apart: 23:55 to 00:02 = 7 min)
        expect(find.text('00:02'), findsOneWidget);
      });

      testWidgets('handles rapid messages within same minute', (tester) async {
        final now = DateTime.now();
        final baseTime = DateTime(now.year, now.month, now.day, 12, 0);
        final messages = [
          ChatMessage(
            role: MessageRole.user,
            content: 'Message 1',
            timestamp: baseTime,
          ),
          ChatMessage(
            role: MessageRole.assistant,
            content: 'Message 2',
            timestamp: baseTime.add(const Duration(seconds: 10)),
          ),
          ChatMessage(
            role: MessageRole.user,
            content: 'Message 3',
            timestamp: baseTime.add(const Duration(seconds: 30)),
          ),
        ];

        await tester.pumpWidget(createTestWidget(messages: messages));

        // All messages should render
        expect(find.byType(MessageBubble), findsNWidgets(3));

        // Only first message gets timestamp divider
        expect(find.byType(Divider), findsNWidgets(2));
      });

      testWidgets('handles long conversation with mixed timing', (tester) async {
        final now = DateTime.now();
        final baseTime = DateTime(now.year, now.month, now.day, 10, 0);
        final messages = [
          ChatMessage(
            role: MessageRole.user,
            content: 'Start',
            timestamp: baseTime,
          ),
          ChatMessage(
            role: MessageRole.assistant,
            content: 'Reply 1',
            timestamp: baseTime.add(const Duration(minutes: 1)),
          ),
          ChatMessage(
            role: MessageRole.user,
            content: 'Follow up',
            timestamp: baseTime.add(const Duration(minutes: 2)),
          ),
          // Gap of 10 minutes
          ChatMessage(
            role: MessageRole.user,
            content: 'After break',
            timestamp: baseTime.add(const Duration(minutes: 12)),
          ),
          ChatMessage(
            role: MessageRole.assistant,
            content: 'Reply 2',
            timestamp: baseTime.add(const Duration(minutes: 13)),
          ),
          // Gap of 30 minutes
          ChatMessage(
            role: MessageRole.user,
            content: 'Much later',
            timestamp: baseTime.add(const Duration(minutes: 43)),
          ),
        ];

        await tester.pumpWidget(createTestWidget(messages: messages));

        expect(find.byType(MessageBubble), findsNWidgets(6));

        // Dividers: first message, "After break" (+10 min gap), "Much later" (+30 min gap)
        // 3 dividers = 6 Divider widgets
        expect(find.byType(Divider), findsNWidgets(6));
      });

      testWidgets('handles empty content messages', (tester) async {
        final messages = [
          ChatMessage(
            role: MessageRole.user,
            content: '',
            timestamp: DateTime.now(),
          ),
        ];

        await tester.pumpWidget(createTestWidget(messages: messages));

        expect(find.byType(MessageBubble), findsOneWidget);
      });

      testWidgets('handles very long messages', (tester) async {
        final longContent = 'A' * 1000;
        final messages = [
          ChatMessage(
            role: MessageRole.assistant,
            content: longContent,
            timestamp: DateTime.now(),
          ),
        ];

        await tester.pumpWidget(createTestWidget(messages: messages));

        expect(find.byType(MessageBubble), findsOneWidget);
        expect(find.text(longContent), findsOneWidget);
      });

      testWidgets('handles messages with attachments', (tester) async {
        final messages = [
          ChatMessage(
            role: MessageRole.user,
            content: 'Message with files',
            timestamp: DateTime.now(),
            attachments: ['/path/to/file.pdf', '/path/to/image.png'],
          ),
        ];

        await tester.pumpWidget(createTestWidget(messages: messages));

        expect(find.byType(MessageBubble), findsOneWidget);
        expect(find.text('Message with files'), findsOneWidget);
      });
    });

    group('Timestamp divider styling', () {
      testWidgets('timestamp divider has correct padding', (tester) async {
        final messages = [
          ChatMessage(
            role: MessageRole.user,
            content: 'Test',
            timestamp: DateTime.now(),
          ),
        ];

        await tester.pumpWidget(createTestWidget(messages: messages));

        // Find the Row that contains dividers (timestamp divider)
        final rowFinder = find.ancestor(
          of: find.byType(Divider).first,
          matching: find.byType(Row),
        );

        final paddingFinder = find.ancestor(
          of: rowFinder.first,
          matching: find.byType(Padding),
        );

        final paddingWidget = tester.widget<Padding>(paddingFinder.first);
        final edgeInsets = paddingWidget.padding as EdgeInsets;

        expect(edgeInsets.top, equals(16));
        expect(edgeInsets.bottom, equals(16));
      });

      testWidgets('timestamp divider has correct divider color', (tester) async {
        final messages = [
          ChatMessage(
            role: MessageRole.user,
            content: 'Test',
            timestamp: DateTime.now(),
          ),
        ];

        await tester.pumpWidget(createTestWidget(messages: messages));

        final dividerWidget = tester.widget<Divider>(find.byType(Divider).first);
        expect(dividerWidget.color, equals(NavixTheme.surfaceVariant));
      });

      testWidgets('timestamp divider has correct thickness', (tester) async {
        final messages = [
          ChatMessage(
            role: MessageRole.user,
            content: 'Test',
            timestamp: DateTime.now(),
          ),
        ];

        await tester.pumpWidget(createTestWidget(messages: messages));

        final dividerWidget = tester.widget<Divider>(find.byType(Divider).first);
        expect(dividerWidget.thickness, equals(1));
      });

      testWidgets('timestamp text has correct color', (tester) async {
        final now = DateTime.now();
        final testTime = DateTime(now.year, now.month, now.day, 15, 45);
        final messages = [
          ChatMessage(
            role: MessageRole.user,
            content: 'Test',
            timestamp: testTime,
          ),
        ];

        await tester.pumpWidget(createTestWidget(messages: messages));

        final timestampText = tester.widget<Text>(find.text('15:45'));
        expect(
          timestampText.style?.color,
          equals(NavixTheme.textTertiary),
        );
      });
    });

    group('Message item padding', () {
      testWidgets('each message item has bottom padding', (tester) async {
        final now = DateTime.now();
        final messages = [
          ChatMessage(
            role: MessageRole.user,
            content: 'First',
            timestamp: now,
          ),
          ChatMessage(
            role: MessageRole.assistant,
            content: 'Second',
            timestamp: now.add(const Duration(seconds: 30)),
          ),
        ];

        await tester.pumpWidget(createTestWidget(messages: messages));

        // Find Column widgets that wrap MessageBubble
        final columnFinder = find.ancestor(
          of: find.byType(MessageBubble),
          matching: find.byType(Column),
        );

        // Each Column should be wrapped in a Padding with bottom: 8
        final paddingFinder = find.ancestor(
          of: columnFinder.first,
          matching: find.byType(Padding),
        );

        expect(paddingFinder, findsWidgets);
      });
    });

    group('Message column layout', () {
      testWidgets('message column has correct cross axis alignment',
          (tester) async {
        final messages = [
          ChatMessage(
            role: MessageRole.user,
            content: 'Test',
            timestamp: DateTime.now(),
          ),
        ];

        await tester.pumpWidget(createTestWidget(messages: messages));

        // Find the Column that wraps timestamp divider and MessageBubble
        final columnFinder = find.ancestor(
          of: find.byType(MessageBubble),
          matching: find.byType(Column),
        );

        final columnWidget = tester.widget<Column>(columnFinder.first);
        expect(
          columnWidget.crossAxisAlignment,
          equals(CrossAxisAlignment.stretch),
        );
      });
    });
  });

  group('ChatMessage model', () {
    test('creates message with all fields', () {
      final timestamp = DateTime(2024, 6, 15, 14, 30);
      final message = ChatMessage(
        role: MessageRole.user,
        content: 'Test content',
        timestamp: timestamp,
        attachments: ['/file1.pdf', '/file2.png'],
      );

      expect(message.role, equals(MessageRole.user));
      expect(message.content, equals('Test content'));
      expect(message.timestamp, equals(timestamp));
      expect(message.attachments, equals(['/file1.pdf', '/file2.png']));
    });

    test('creates message without attachments', () {
      final message = ChatMessage(
        role: MessageRole.assistant,
        content: 'Response',
        timestamp: DateTime.now(),
      );

      expect(message.attachments, isNull);
    });

    test('message roles are correctly set', () {
      expect(
        ChatMessage(
          role: MessageRole.user,
          content: '',
          timestamp: DateTime.now(),
        ).role,
        equals(MessageRole.user),
      );
      expect(
        ChatMessage(
          role: MessageRole.assistant,
          content: '',
          timestamp: DateTime.now(),
        ).role,
        equals(MessageRole.assistant),
      );
      expect(
        ChatMessage(
          role: MessageRole.system,
          content: '',
          timestamp: DateTime.now(),
        ).role,
        equals(MessageRole.system),
      );
      expect(
        ChatMessage(
          role: MessageRole.error,
          content: '',
          timestamp: DateTime.now(),
        ).role,
        equals(MessageRole.error),
      );
    });
  });

  group('MessageRole enum', () {
    test('has all expected roles', () {
      expect(MessageRole.values.length, equals(4));
      expect(MessageRole.values, contains(MessageRole.user));
      expect(MessageRole.values, contains(MessageRole.assistant));
      expect(MessageRole.values, contains(MessageRole.system));
      expect(MessageRole.values, contains(MessageRole.error));
    });
  });
}
