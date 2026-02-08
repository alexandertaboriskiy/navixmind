import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navixmind/app/theme.dart';
import 'package:navixmind/features/chat/presentation/chat_screen.dart';
import 'package:navixmind/features/chat/presentation/widgets/message_bubble.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  group('Role indicators', () {
    testWidgets('user role shows ● indicator', (tester) async {
      await tester.pumpWidget(createTestWidget(ChatMessage(
        role: MessageRole.user,
        content: 'User message',
        timestamp: DateTime.now(),
      )));

      expect(find.text('●'), findsOneWidget);
    });

    testWidgets('assistant role shows ◆ indicator', (tester) async {
      await tester.pumpWidget(createTestWidget(ChatMessage(
        role: MessageRole.assistant,
        content: 'Assistant message',
        timestamp: DateTime.now(),
      )));

      expect(find.text('◆'), findsOneWidget);
    });

    testWidgets('system messages do not show role indicator', (tester) async {
      await tester.pumpWidget(createTestWidget(ChatMessage(
        role: MessageRole.system,
        content: 'System message',
        timestamp: DateTime.now(),
      )));

      // System messages have no role indicator (● for user, ◆ for assistant)
      expect(find.text('●'), findsNothing);
      expect(find.text('◆'), findsNothing);
    });

    testWidgets('error messages do not show role indicator', (tester) async {
      await tester.pumpWidget(createTestWidget(ChatMessage(
        role: MessageRole.error,
        content: 'Error message',
        timestamp: DateTime.now(),
      )));

      expect(find.text('●'), findsNothing);
      expect(find.text('◆'), findsNothing);
    });

    testWidgets('user indicator is on the right side', (tester) async {
      await tester.pumpWidget(createTestWidget(ChatMessage(
        role: MessageRole.user,
        content: 'Right aligned',
        timestamp: DateTime.now(),
      )));

      final row = tester.widget<Row>(find.byType(Row).first);
      expect(row.mainAxisAlignment, MainAxisAlignment.end);
    });

    testWidgets('assistant indicator is on the left side', (tester) async {
      await tester.pumpWidget(createTestWidget(ChatMessage(
        role: MessageRole.assistant,
        content: 'Left aligned',
        timestamp: DateTime.now(),
      )));

      final row = tester.widget<Row>(find.byType(Row).first);
      expect(row.mainAxisAlignment, MainAxisAlignment.start);
    });
  });

  group('Background colors', () {
    testWidgets('user message has primary color background', (tester) async {
      await tester.pumpWidget(createTestWidget(ChatMessage(
        role: MessageRole.user,
        content: 'User bg',
        timestamp: DateTime.now(),
      )));

      // Find the decorated Container wrapping the message content
      final containers = tester.widgetList<Container>(find.byType(Container));
      final decoratedContainers = containers.where((c) {
        final dec = c.decoration;
        if (dec is BoxDecoration && dec.color != null) {
          return dec.color == NavixTheme.primary.withOpacity(0.15);
        }
        return false;
      });
      expect(decoratedContainers, isNotEmpty);
    });

    testWidgets('assistant message has surface background', (tester) async {
      await tester.pumpWidget(createTestWidget(ChatMessage(
        role: MessageRole.assistant,
        content: 'Assistant bg',
        timestamp: DateTime.now(),
      )));

      final containers = tester.widgetList<Container>(find.byType(Container));
      final surfaceContainers = containers.where((c) {
        final dec = c.decoration;
        if (dec is BoxDecoration && dec.color != null) {
          return dec.color == NavixTheme.surface;
        }
        return false;
      });
      expect(surfaceContainers, isNotEmpty);
    });

    testWidgets('system message has surfaceVariant background', (tester) async {
      await tester.pumpWidget(createTestWidget(ChatMessage(
        role: MessageRole.system,
        content: 'System bg',
        timestamp: DateTime.now(),
      )));

      final containers = tester.widgetList<Container>(find.byType(Container));
      final variantContainers = containers.where((c) {
        final dec = c.decoration;
        if (dec is BoxDecoration && dec.color != null) {
          return dec.color == NavixTheme.surfaceVariant;
        }
        return false;
      });
      expect(variantContainers, isNotEmpty);
    });

    testWidgets('error message has error color background', (tester) async {
      await tester.pumpWidget(createTestWidget(ChatMessage(
        role: MessageRole.error,
        content: 'Error bg',
        timestamp: DateTime.now(),
      )));

      final containers = tester.widgetList<Container>(find.byType(Container));
      final errorContainers = containers.where((c) {
        final dec = c.decoration;
        if (dec is BoxDecoration && dec.color != null) {
          return dec.color == NavixTheme.error.withOpacity(0.15);
        }
        return false;
      });
      expect(errorContainers, isNotEmpty);
    });
  });

  group('Error message styling', () {
    testWidgets('error shows warning icon', (tester) async {
      await tester.pumpWidget(createTestWidget(ChatMessage(
        role: MessageRole.error,
        content: 'Something broke',
        timestamp: DateTime.now(),
      )));

      expect(find.text(NavixTheme.iconWarning), findsOneWidget);
    });

    testWidgets('error text has error color', (tester) async {
      await tester.pumpWidget(createTestWidget(ChatMessage(
        role: MessageRole.error,
        content: 'Error text color',
        timestamp: DateTime.now(),
      )));

      final selectableText = tester.widget<SelectableText>(
        find.widgetWithText(SelectableText, 'Error text color'),
      );
      expect(selectableText.style?.color, NavixTheme.error);
    });

    testWidgets('error message has border', (tester) async {
      await tester.pumpWidget(createTestWidget(ChatMessage(
        role: MessageRole.error,
        content: 'Bordered error',
        timestamp: DateTime.now(),
      )));

      // The error container should have a border
      final containers = tester.widgetList<Container>(find.byType(Container));
      final borderedContainers = containers.where((c) {
        final dec = c.decoration;
        if (dec is BoxDecoration && dec.border != null) {
          return true;
        }
        return false;
      });
      expect(borderedContainers, isNotEmpty);
    });

    testWidgets('error icon and text in row layout', (tester) async {
      await tester.pumpWidget(createTestWidget(ChatMessage(
        role: MessageRole.error,
        content: 'Error layout',
        timestamp: DateTime.now(),
      )));

      // Both icon and text should be visible
      expect(find.text(NavixTheme.iconWarning), findsOneWidget);
      expect(find.text('Error layout'), findsOneWidget);
    });
  });

  group('Accessibility labels', () {
    testWidgets('user message contains "You said: <content>"', (tester) async {
      await tester.pumpWidget(createTestWidget(ChatMessage(
        role: MessageRole.user,
        content: 'My question',
        timestamp: DateTime.now(),
      )));

      final semantics = tester.getSemantics(find.byType(MessageBubble));
      expect(semantics.label, contains('You said: My question'));
    });

    testWidgets('assistant message contains "NavixMind replied: <content>"', (tester) async {
      await tester.pumpWidget(createTestWidget(ChatMessage(
        role: MessageRole.assistant,
        content: 'My answer',
        timestamp: DateTime.now(),
      )));

      final semantics = tester.getSemantics(find.byType(MessageBubble));
      expect(semantics.label, contains('NavixMind replied: My answer'));
    });

    testWidgets('system message contains "System message: <content>"', (tester) async {
      await tester.pumpWidget(createTestWidget(ChatMessage(
        role: MessageRole.system,
        content: 'Info text',
        timestamp: DateTime.now(),
      )));

      final semantics = tester.getSemantics(find.byType(MessageBubble));
      expect(semantics.label, contains('System message: Info text'));
    });

    testWidgets('error message contains "Error: <content>"', (tester) async {
      await tester.pumpWidget(createTestWidget(ChatMessage(
        role: MessageRole.error,
        content: 'Connection failed',
        timestamp: DateTime.now(),
      )));

      final semantics = tester.getSemantics(find.byType(MessageBubble));
      expect(semantics.label, contains('Error: Connection failed'));
    });

    testWidgets('all roles have "Long press to copy" hint', (tester) async {
      for (final role in MessageRole.values) {
        await tester.pumpWidget(createTestWidget(ChatMessage(
          role: role,
          content: 'Hint test for $role',
          timestamp: DateTime.now(),
        )));

        final semantics = tester.getSemantics(find.byType(MessageBubble));
        expect(semantics.hint, 'Long press to copy',
            reason: '$role should have long press hint');
      }
    });
  });

  group('Code block rendering', () {
    testWidgets('single code block with language label', (tester) async {
      await tester.pumpWidget(createTestWidget(ChatMessage(
        role: MessageRole.assistant,
        content: 'Here is code:\n```python\nprint("hello")\n```',
        timestamp: DateTime.now(),
      )));

      expect(find.text('python'), findsOneWidget);
      expect(find.text('print("hello")'), findsOneWidget);
    });

    testWidgets('code block without language label', (tester) async {
      await tester.pumpWidget(createTestWidget(ChatMessage(
        role: MessageRole.assistant,
        content: '```\nplain code\n```',
        timestamp: DateTime.now(),
      )));

      expect(find.text('plain code'), findsOneWidget);
    });

    testWidgets('multiple code blocks with different languages', (tester) async {
      await tester.pumpWidget(createTestWidget(ChatMessage(
        role: MessageRole.assistant,
        content: '```dart\nvoid main() {}\n```\nThen:\n```bash\necho hi\n```',
        timestamp: DateTime.now(),
      )));

      expect(find.text('dart'), findsOneWidget);
      expect(find.text('bash'), findsOneWidget);
      expect(find.text('void main() {}'), findsOneWidget);
      expect(find.text('echo hi'), findsOneWidget);
    });

    testWidgets('text before code block is rendered', (tester) async {
      await tester.pumpWidget(createTestWidget(ChatMessage(
        role: MessageRole.assistant,
        content: 'Before code\n```\ncode\n```',
        timestamp: DateTime.now(),
      )));

      expect(find.text('Before code'), findsOneWidget);
      expect(find.text('code'), findsOneWidget);
    });

    testWidgets('text after code block is rendered', (tester) async {
      await tester.pumpWidget(createTestWidget(ChatMessage(
        role: MessageRole.assistant,
        content: '```\ncode\n```\nAfter code',
        timestamp: DateTime.now(),
      )));

      expect(find.text('After code'), findsOneWidget);
    });

    testWidgets('empty code block renders without crash', (tester) async {
      await tester.pumpWidget(createTestWidget(ChatMessage(
        role: MessageRole.assistant,
        content: '```\n\n```',
        timestamp: DateTime.now(),
      )));

      // Should not crash
      expect(find.byType(MessageBubble), findsOneWidget);
    });

    testWidgets('code block with special characters', (tester) async {
      await tester.pumpWidget(createTestWidget(ChatMessage(
        role: MessageRole.assistant,
        content: '```python\nresult = a < b & c > d\n```',
        timestamp: DateTime.now(),
      )));

      expect(find.textContaining('result = a < b'), findsOneWidget);
    });

    testWidgets('code block with multiline content', (tester) async {
      await tester.pumpWidget(createTestWidget(ChatMessage(
        role: MessageRole.assistant,
        content: '```python\ndef hello():\n    print("world")\n    return True\n```',
        timestamp: DateTime.now(),
      )));

      expect(find.textContaining('def hello():'), findsOneWidget);
    });

    testWidgets('code block uses monospace style', (tester) async {
      await tester.pumpWidget(createTestWidget(ChatMessage(
        role: MessageRole.assistant,
        content: '```\nmonospaced text\n```',
        timestamp: DateTime.now(),
      )));

      // Code should be in a SelectableText widget
      expect(find.text('monospaced text'), findsOneWidget);
    });
  });

  group('Context menu', () {
    testWidgets('long press shows copy option', (tester) async {
      await tester.pumpWidget(createTestWidget(ChatMessage(
        role: MessageRole.assistant,
        content: 'Copy this content',
        timestamp: DateTime.now(),
      )));

      // Long press on the message
      final center = tester.getCenter(find.text('Copy this content'));
      final gesture = await tester.startGesture(center);
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.text('Copy'), findsOneWidget);
    });

    testWidgets('tapping copy dismisses bottom sheet', (tester) async {
      await tester.pumpWidget(createTestWidget(ChatMessage(
        role: MessageRole.user,
        content: 'Copy and dismiss',
        timestamp: DateTime.now(),
      )));

      final center = tester.getCenter(find.text('Copy and dismiss'));
      final gesture = await tester.startGesture(center);
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.up();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Copy'));
      await tester.pumpAndSettle();

      expect(find.text('Copy'), findsNothing);
    });

    testWidgets('long press on error message shows copy', (tester) async {
      await tester.pumpWidget(createTestWidget(ChatMessage(
        role: MessageRole.error,
        content: 'Error to copy',
        timestamp: DateTime.now(),
      )));

      // Long press the warning icon area (not SelectableText which captures gesture)
      final center = tester.getCenter(find.text(NavixTheme.iconWarning));
      final gesture = await tester.startGesture(center);
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.text('Copy'), findsOneWidget);
    });

    testWidgets('long press on system message shows copy', (tester) async {
      await tester.pumpWidget(createTestWidget(ChatMessage(
        role: MessageRole.system,
        content: 'System to copy',
        timestamp: DateTime.now(),
      )));

      final center = tester.getCenter(find.text('System to copy'));
      final gesture = await tester.startGesture(center);
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.text('Copy'), findsOneWidget);
    });

    testWidgets('copy option appears in bottom sheet via role indicator', (tester) async {
      await tester.pumpWidget(createTestWidget(ChatMessage(
        role: MessageRole.assistant,
        content: 'Check option',
        timestamp: DateTime.now(),
      )));

      // Long press on the role indicator to avoid SelectableText gesture competition
      final center = tester.getCenter(find.text('◆'));
      final gesture = await tester.startGesture(center);
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.up();
      await tester.pumpAndSettle();

      // Verify the copy option appears in a ListTile in the bottom sheet
      expect(find.widgetWithText(ListTile, 'Copy'), findsOneWidget);
    });
  });

  group('Content edge cases', () {
    testWidgets('empty content string renders', (tester) async {
      await tester.pumpWidget(createTestWidget(ChatMessage(
        role: MessageRole.assistant,
        content: '',
        timestamp: DateTime.now(),
      )));

      // Should not crash
      expect(find.byType(MessageBubble), findsOneWidget);
    });

    testWidgets('very long single-line content wraps', (tester) async {
      final longContent = 'A' * 1000;
      await tester.pumpWidget(createTestWidget(ChatMessage(
        role: MessageRole.assistant,
        content: longContent,
        timestamp: DateTime.now(),
      )));

      expect(find.byType(MessageBubble), findsOneWidget);
    });

    testWidgets('content with newlines preserves formatting', (tester) async {
      await tester.pumpWidget(createTestWidget(ChatMessage(
        role: MessageRole.assistant,
        content: 'Line 1\nLine 2\nLine 3',
        timestamp: DateTime.now(),
      )));

      expect(find.textContaining('Line 1'), findsOneWidget);
    });

    testWidgets('content with unicode characters', (tester) async {
      await tester.pumpWidget(createTestWidget(ChatMessage(
        role: MessageRole.assistant,
        content: '日本語テスト 🎉 αβγ',
        timestamp: DateTime.now(),
      )));

      expect(find.textContaining('日本語'), findsOneWidget);
    });

    testWidgets('content with HTML-like tags renders as text', (tester) async {
      await tester.pumpWidget(createTestWidget(ChatMessage(
        role: MessageRole.assistant,
        content: '<b>bold</b> <script>alert(1)</script>',
        timestamp: DateTime.now(),
      )));

      expect(find.textContaining('<b>bold</b>'), findsOneWidget);
    });

    testWidgets('content with only whitespace renders', (tester) async {
      await tester.pumpWidget(createTestWidget(ChatMessage(
        role: MessageRole.assistant,
        content: '   \n\n   ',
        timestamp: DateTime.now(),
      )));

      expect(find.byType(MessageBubble), findsOneWidget);
    });

    testWidgets('content with backticks but not code block', (tester) async {
      await tester.pumpWidget(createTestWidget(ChatMessage(
        role: MessageRole.assistant,
        content: 'Use `inline code` with backticks',
        timestamp: DateTime.now(),
      )));

      // Single backticks should render as plain text (no code block parsing)
      expect(find.textContaining('Use `inline code` with backticks'), findsOneWidget);
    });

    testWidgets('content with triple backtick but no closing', (tester) async {
      await tester.pumpWidget(createTestWidget(ChatMessage(
        role: MessageRole.assistant,
        content: 'Before ```python\nprint("open")\nNo close',
        timestamp: DateTime.now(),
      )));

      // Should contain backtick-containing text but handle it
      expect(find.byType(MessageBubble), findsOneWidget);
    });
  });

  group('SelectableText', () {
    testWidgets('assistant plain text is selectable', (tester) async {
      await tester.pumpWidget(createTestWidget(ChatMessage(
        role: MessageRole.assistant,
        content: 'Selectable text',
        timestamp: DateTime.now(),
      )));

      expect(find.byType(SelectableText), findsAtLeastNWidgets(1));
    });

    testWidgets('user plain text is selectable', (tester) async {
      await tester.pumpWidget(createTestWidget(ChatMessage(
        role: MessageRole.user,
        content: 'User selectable text',
        timestamp: DateTime.now(),
      )));

      expect(find.byType(SelectableText), findsAtLeastNWidgets(1));
    });

    testWidgets('system text is selectable', (tester) async {
      await tester.pumpWidget(createTestWidget(ChatMessage(
        role: MessageRole.system,
        content: 'System selectable text',
        timestamp: DateTime.now(),
      )));

      expect(find.byType(SelectableText), findsAtLeastNWidgets(1));
    });

    testWidgets('error text is selectable', (tester) async {
      await tester.pumpWidget(createTestWidget(ChatMessage(
        role: MessageRole.error,
        content: 'Error selectable text',
        timestamp: DateTime.now(),
      )));

      expect(find.byType(SelectableText), findsAtLeastNWidgets(1));
    });
  });

  group('Message alignment', () {
    testWidgets('user messages right-aligned', (tester) async {
      await tester.pumpWidget(createTestWidget(ChatMessage(
        role: MessageRole.user,
        content: 'Right',
        timestamp: DateTime.now(),
      )));
      final row = tester.widget<Row>(find.byType(Row).first);
      expect(row.mainAxisAlignment, MainAxisAlignment.end);
    });

    testWidgets('assistant messages left-aligned', (tester) async {
      await tester.pumpWidget(createTestWidget(ChatMessage(
        role: MessageRole.assistant,
        content: 'Left',
        timestamp: DateTime.now(),
      )));
      final row = tester.widget<Row>(find.byType(Row).first);
      expect(row.mainAxisAlignment, MainAxisAlignment.start);
    });

    testWidgets('system messages left-aligned', (tester) async {
      await tester.pumpWidget(createTestWidget(ChatMessage(
        role: MessageRole.system,
        content: 'Left',
        timestamp: DateTime.now(),
      )));
      final row = tester.widget<Row>(find.byType(Row).first);
      expect(row.mainAxisAlignment, MainAxisAlignment.start);
    });

    testWidgets('error messages left-aligned', (tester) async {
      await tester.pumpWidget(createTestWidget(ChatMessage(
        role: MessageRole.error,
        content: 'Left',
        timestamp: DateTime.now(),
      )));
      final row = tester.widget<Row>(find.byType(Row).first);
      expect(row.mainAxisAlignment, MainAxisAlignment.start);
    });
  });

  group('ChatMessage model', () {
    test('creates with required fields', () {
      final ts = DateTime(2025, 6, 15, 10, 30);
      final msg = ChatMessage(
        role: MessageRole.user,
        content: 'Hello',
        timestamp: ts,
      );
      expect(msg.role, MessageRole.user);
      expect(msg.content, 'Hello');
      expect(msg.timestamp, ts);
      expect(msg.attachments, isNull);
    });

    test('creates with attachments', () {
      final msg = ChatMessage(
        role: MessageRole.user,
        content: 'With files',
        timestamp: DateTime.now(),
        attachments: ['/path/a.jpg', '/path/b.pdf'],
      );
      expect(msg.attachments, hasLength(2));
      expect(msg.attachments![0], '/path/a.jpg');
      expect(msg.attachments![1], '/path/b.pdf');
    });

    test('allows empty attachments list', () {
      final msg = ChatMessage(
        role: MessageRole.user,
        content: 'No files',
        timestamp: DateTime.now(),
        attachments: [],
      );
      expect(msg.attachments, isEmpty);
    });

    test('allows empty content', () {
      final msg = ChatMessage(
        role: MessageRole.assistant,
        content: '',
        timestamp: DateTime.now(),
      );
      expect(msg.content, '');
    });

    test('timestamp precision preserved', () {
      final precise = DateTime(2025, 1, 15, 14, 30, 45, 123, 456);
      final msg = ChatMessage(
        role: MessageRole.system,
        content: 'test',
        timestamp: precise,
      );
      expect(msg.timestamp.millisecond, 123);
      expect(msg.timestamp.microsecond, 456);
    });

    test('all roles are valid', () {
      for (final role in MessageRole.values) {
        final msg = ChatMessage(
          role: role,
          content: 'test $role',
          timestamp: DateTime.now(),
        );
        expect(msg.role, role);
      }
    });

    test('content can contain file link format', () {
      final msg = ChatMessage(
        role: MessageRole.system,
        content: '📎 File: /data/output/result.pdf',
        timestamp: DateTime.now(),
      );
      expect(msg.content.startsWith('📎 File:'), isTrue);
    });
  });

  group('MessageRole enum', () {
    test('has exactly 4 values', () {
      expect(MessageRole.values.length, 4);
    });

    test('contains user', () {
      expect(MessageRole.values, contains(MessageRole.user));
    });

    test('contains assistant', () {
      expect(MessageRole.values, contains(MessageRole.assistant));
    });

    test('contains system', () {
      expect(MessageRole.values, contains(MessageRole.system));
    });

    test('contains error', () {
      expect(MessageRole.values, contains(MessageRole.error));
    });
  });
}
