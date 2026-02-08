import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navixmind/app/theme.dart';
import 'package:navixmind/features/chat/presentation/chat_screen.dart';
import 'package:navixmind/features/chat/presentation/widgets/message_bubble.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late List<MethodCall> fileChannelCalls;
  late bool openFileResult;
  late bool openFileShouldThrow;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('msg_bubble_test_');
    fileChannelCalls = [];
    openFileResult = true;
    openFileShouldThrow = false;

    // Mock the file opener MethodChannel
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('ai.navixmind/file_opener'),
      (MethodCall call) async {
        fileChannelCalls.add(call);
        if (openFileShouldThrow) {
          throw PlatformException(code: 'OPEN_FAILED', message: 'Mock error');
        }
        return openFileResult;
      },
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('ai.navixmind/file_opener'),
      null,
    );
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  String createTempFile(String name, {int size = 100}) {
    final file = File('${tempDir.path}/$name');
    file.writeAsBytesSync(List.filled(size, 0));
    return file.path;
  }

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

  /// Taps and runs the async onTap handler (File.exists + channel call) to completion.
  /// Uses tester.runAsync to allow real async I/O (File.exists) to resolve.
  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    // runAsync allows real async I/O (File.exists, channel calls) to complete
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
  }

  group('MessageBubble file link rendering', () {
    testWidgets('detects file link message format', (tester) async {
      final path = createTempFile('test.pdf');
      final message = ChatMessage(
        role: MessageRole.assistant,
        content: '📎 File: $path',
        timestamp: DateTime.now(),
      );

      await tester.pumpWidget(createTestWidget(message));

      expect(find.byIcon(Icons.insert_drive_file), findsOneWidget);
      expect(find.byIcon(Icons.share), findsOneWidget);
    });

    testWidgets('displays filename extracted from path', (tester) async {
      final path = createTempFile('report.pdf');
      final message = ChatMessage(
        role: MessageRole.assistant,
        content: '📎 File: $path',
        timestamp: DateTime.now(),
      );

      await tester.pumpWidget(createTestWidget(message));

      expect(find.text('report.pdf'), findsOneWidget);
    });

    testWidgets('displays filename with spaces', (tester) async {
      final file = File('${tempDir.path}/my report 2024.pdf');
      file.writeAsBytesSync(List.filled(10, 0));

      final message = ChatMessage(
        role: MessageRole.assistant,
        content: '📎 File: ${file.path}',
        timestamp: DateTime.now(),
      );

      await tester.pumpWidget(createTestWidget(message));

      expect(find.text('my report 2024.pdf'), findsOneWidget);
    });

    testWidgets('trims whitespace from file path', (tester) async {
      final path = createTempFile('trimmed.txt');
      final message = ChatMessage(
        role: MessageRole.assistant,
        content: '📎 File:   $path   ',
        timestamp: DateTime.now(),
      );

      await tester.pumpWidget(createTestWidget(message));

      expect(find.text('trimmed.txt'), findsOneWidget);
    });

    testWidgets('shows file icon and share icon', (tester) async {
      final path = createTempFile('doc.pdf');
      final message = ChatMessage(
        role: MessageRole.assistant,
        content: '📎 File: $path',
        timestamp: DateTime.now(),
      );

      await tester.pumpWidget(createTestWidget(message));

      expect(find.byIcon(Icons.insert_drive_file), findsOneWidget);
      expect(find.byIcon(Icons.share), findsOneWidget);
    });

    testWidgets('filename has primary color and underline styling', (tester) async {
      final path = createTempFile('styled.pdf');
      final message = ChatMessage(
        role: MessageRole.assistant,
        content: '📎 File: $path',
        timestamp: DateTime.now(),
      );

      await tester.pumpWidget(createTestWidget(message));

      final textWidget = tester.widget<Text>(find.text('styled.pdf'));
      expect(textWidget.style?.color, equals(NavixTheme.primary));
      expect(textWidget.style?.decoration, equals(TextDecoration.underline));
    });

    testWidgets('non-file messages render as plain text', (tester) async {
      final message = ChatMessage(
        role: MessageRole.assistant,
        content: 'This is a regular message',
        timestamp: DateTime.now(),
      );

      await tester.pumpWidget(createTestWidget(message));

      expect(find.byIcon(Icons.insert_drive_file), findsNothing);
      expect(find.byIcon(Icons.share), findsNothing);
      expect(find.text('This is a regular message'), findsOneWidget);
    });

    testWidgets('message starting with emoji but not file prefix is plain text', (tester) async {
      final message = ChatMessage(
        role: MessageRole.assistant,
        content: '📎 This is not a file link',
        timestamp: DateTime.now(),
      );

      await tester.pumpWidget(createTestWidget(message));

      expect(find.byIcon(Icons.insert_drive_file), findsNothing);
    });

    testWidgets('handles deeply nested file path', (tester) async {
      final dir = Directory('${tempDir.path}/a/b/c/d/e');
      dir.createSync(recursive: true);
      final file = File('${dir.path}/deep.txt');
      file.writeAsBytesSync([1, 2, 3]);

      final message = ChatMessage(
        role: MessageRole.assistant,
        content: '📎 File: ${file.path}',
        timestamp: DateTime.now(),
      );

      await tester.pumpWidget(createTestWidget(message));

      expect(find.text('deep.txt'), findsOneWidget);
    });

    testWidgets('handles filename with multiple dots', (tester) async {
      final path = createTempFile('archive.tar.gz');
      final message = ChatMessage(
        role: MessageRole.assistant,
        content: '📎 File: $path',
        timestamp: DateTime.now(),
      );

      await tester.pumpWidget(createTestWidget(message));

      expect(find.text('archive.tar.gz'), findsOneWidget);
    });

    testWidgets('handles filename with no extension', (tester) async {
      final path = createTempFile('Makefile');
      final message = ChatMessage(
        role: MessageRole.assistant,
        content: '📎 File: $path',
        timestamp: DateTime.now(),
      );

      await tester.pumpWidget(createTestWidget(message));

      expect(find.text('Makefile'), findsOneWidget);
    });

    testWidgets('file link in user message renders as file link', (tester) async {
      final path = createTempFile('user_file.pdf');
      final message = ChatMessage(
        role: MessageRole.user,
        content: '📎 File: $path',
        timestamp: DateTime.now(),
      );

      await tester.pumpWidget(createTestWidget(message));

      expect(find.byIcon(Icons.insert_drive_file), findsOneWidget);
    });

    testWidgets('path with special characters in filename', (tester) async {
      final file = File('${tempDir.path}/résumé_(1).pdf');
      file.writeAsBytesSync([1]);

      final message = ChatMessage(
        role: MessageRole.assistant,
        content: '📎 File: ${file.path}',
        timestamp: DateTime.now(),
      );

      await tester.pumpWidget(createTestWidget(message));

      expect(find.textContaining('résumé'), findsOneWidget);
    });

    testWidgets('very long filename is rendered with overflow handling', (tester) async {
      final longName = 'a' * 200 + '.pdf';
      final file = File('${tempDir.path}/$longName');
      file.writeAsBytesSync([1]);

      final message = ChatMessage(
        role: MessageRole.assistant,
        content: '📎 File: ${file.path}',
        timestamp: DateTime.now(),
      );

      await tester.pumpWidget(createTestWidget(message));

      // Flexible widget handles overflow; file icon still visible
      expect(find.byIcon(Icons.insert_drive_file), findsOneWidget);
    });
  });

  group('MessageBubble file open action', () {
    testWidgets('tapping filename calls openFile on channel', (tester) async {
      final path = createTempFile('open_me.pdf');
      openFileResult = true;

      final message = ChatMessage(
        role: MessageRole.assistant,
        content: '📎 File: $path',
        timestamp: DateTime.now(),
      );

      await tester.pumpWidget(createTestWidget(message));
      await tapAndSettle(tester, find.text('open_me.pdf'));

      expect(fileChannelCalls, hasLength(1));
      expect(fileChannelCalls[0].method, 'openFile');
      expect(fileChannelCalls[0].arguments['path'], path);
    });

    testWidgets('successful open completes without error', (tester) async {
      final path = createTempFile('opens_fine.pdf');
      openFileResult = true;

      final message = ChatMessage(
        role: MessageRole.assistant,
        content: '📎 File: $path',
        timestamp: DateTime.now(),
      );

      await tester.pumpWidget(createTestWidget(message));
      await tapAndSettle(tester, find.text('opens_fine.pdf'));

      expect(fileChannelCalls, hasLength(1));
      expect(fileChannelCalls[0].method, 'openFile');
    });

    testWidgets('non-existent file shows snackbar error', (tester) async {
      final fakePath = '${tempDir.path}/ghost_file.pdf';

      final message = ChatMessage(
        role: MessageRole.assistant,
        content: '📎 File: $fakePath',
        timestamp: DateTime.now(),
      );

      await tester.pumpWidget(createTestWidget(message));
      await tapAndSettle(tester, find.text('ghost_file.pdf'));

      // Should not call openFile
      expect(fileChannelCalls, isEmpty);
      // Should show snackbar
      expect(find.text('File not found: ghost_file.pdf'), findsOneWidget);
    });

    testWidgets('openFile returning false falls back gracefully', (tester) async {
      final path = createTempFile('no_viewer.dat');
      openFileResult = false;

      final message = ChatMessage(
        role: MessageRole.assistant,
        content: '📎 File: $path',
        timestamp: DateTime.now(),
      );

      await tester.pumpWidget(createTestWidget(message));
      await tapAndSettle(tester, find.text('no_viewer.dat'));

      // openFile was called
      expect(fileChannelCalls, hasLength(1));
      // Share.shareXFiles fallback is called but can't easily verify in test
    });

    testWidgets('openFile throwing PlatformException falls back gracefully', (tester) async {
      final path = createTempFile('error_open.pdf');
      openFileShouldThrow = true;

      final message = ChatMessage(
        role: MessageRole.assistant,
        content: '📎 File: $path',
        timestamp: DateTime.now(),
      );

      await tester.pumpWidget(createTestWidget(message));
      await tapAndSettle(tester, find.text('error_open.pdf'));

      // openFile was attempted
      expect(fileChannelCalls, hasLength(1));
      // No crash — error caught
    });

    testWidgets('tapping file icon area also opens file', (tester) async {
      final path = createTempFile('icon_tap.pdf');
      openFileResult = true;

      final message = ChatMessage(
        role: MessageRole.assistant,
        content: '📎 File: $path',
        timestamp: DateTime.now(),
      );

      await tester.pumpWidget(createTestWidget(message));
      await tapAndSettle(tester, find.byIcon(Icons.insert_drive_file));

      expect(fileChannelCalls, hasLength(1));
      expect(fileChannelCalls[0].method, 'openFile');
    });

    testWidgets('openFile sends correct path argument', (tester) async {
      final path = createTempFile('exact_path.pdf');
      openFileResult = true;

      final message = ChatMessage(
        role: MessageRole.assistant,
        content: '📎 File: $path',
        timestamp: DateTime.now(),
      );

      await tester.pumpWidget(createTestWidget(message));
      await tapAndSettle(tester, find.text('exact_path.pdf'));

      expect(fileChannelCalls[0].arguments, isA<Map>());
      expect(fileChannelCalls[0].arguments['path'], equals(path));
    });

    testWidgets('file deleted between render and tap shows snackbar', (tester) async {
      final path = createTempFile('will_delete.pdf');
      final message = ChatMessage(
        role: MessageRole.assistant,
        content: '📎 File: $path',
        timestamp: DateTime.now(),
      );

      await tester.pumpWidget(createTestWidget(message));
      expect(find.text('will_delete.pdf'), findsOneWidget);

      // Delete the file before tapping
      File(path).deleteSync();

      await tapAndSettle(tester, find.text('will_delete.pdf'));

      expect(fileChannelCalls, isEmpty);
      expect(find.text('File not found: will_delete.pdf'), findsOneWidget);
    });
  });

  group('MessageBubble share button', () {
    testWidgets('share button does NOT call openFile', (tester) async {
      final path = createTempFile('share_only.pdf');

      final message = ChatMessage(
        role: MessageRole.assistant,
        content: '📎 File: $path',
        timestamp: DateTime.now(),
      );

      await tester.pumpWidget(createTestWidget(message));
      await tapAndSettle(tester, find.byIcon(Icons.share));

      // openFile should NOT be called
      expect(fileChannelCalls, isEmpty);
    });

    testWidgets('share and open are separate tappable areas', (tester) async {
      final path = createTempFile('two_buttons.pdf');
      final message = ChatMessage(
        role: MessageRole.assistant,
        content: '📎 File: $path',
        timestamp: DateTime.now(),
      );

      await tester.pumpWidget(createTestWidget(message));

      final fileIcon = find.byIcon(Icons.insert_drive_file);
      final shareIcon = find.byIcon(Icons.share);

      expect(fileIcon, findsOneWidget);
      expect(shareIcon, findsOneWidget);

      // They are at different horizontal positions
      final filePos = tester.getCenter(fileIcon);
      final sharePos = tester.getCenter(shareIcon);
      expect(filePos.dx, isNot(equals(sharePos.dx)));
    });

    testWidgets('share icon has tertiary color', (tester) async {
      final path = createTempFile('color_test.pdf');
      final message = ChatMessage(
        role: MessageRole.assistant,
        content: '📎 File: $path',
        timestamp: DateTime.now(),
      );

      await tester.pumpWidget(createTestWidget(message));

      final shareIcon = tester.widget<Icon>(find.byIcon(Icons.share));
      expect(shareIcon.color, equals(NavixTheme.textTertiary));
    });

    testWidgets('file icon has primary color', (tester) async {
      final path = createTempFile('icon_color.pdf');
      final message = ChatMessage(
        role: MessageRole.assistant,
        content: '📎 File: $path',
        timestamp: DateTime.now(),
      );

      await tester.pumpWidget(createTestWidget(message));

      final fileIcon = tester.widget<Icon>(find.byIcon(Icons.insert_drive_file));
      expect(fileIcon.color, equals(NavixTheme.primary));
    });
  });

  group('File link path parsing (unit)', () {
    test('extracts path from standard format', () {
      const content = '📎 File: /data/user/0/ai.navixmind/output/result.pdf';
      final filePath = content.replaceFirst('📎 File: ', '').trim();
      expect(filePath, '/data/user/0/ai.navixmind/output/result.pdf');
    });

    test('extracts filename from path', () {
      const filePath = '/data/user/0/ai.navixmind/output/result.pdf';
      final fileName = filePath.split('/').last;
      expect(fileName, 'result.pdf');
    });

    test('handles path with trailing slash', () {
      const filePath = '/some/path/';
      final fileName = filePath.split('/').last;
      expect(fileName, '');
    });

    test('handles single filename (no directory)', () {
      const filePath = 'just_a_file.txt';
      final fileName = filePath.split('/').last;
      expect(fileName, 'just_a_file.txt');
    });

    test('handles path with spaces', () {
      const content = '📎 File: /data/user/0/My Documents/report final.pdf';
      final filePath = content.replaceFirst('📎 File: ', '').trim();
      final fileName = filePath.split('/').last;
      expect(fileName, 'report final.pdf');
    });

    test('handles path with unicode characters', () {
      const content = '📎 File: /data/output/日本語ファイル.pdf';
      final filePath = content.replaceFirst('📎 File: ', '').trim();
      final fileName = filePath.split('/').last;
      expect(fileName, '日本語ファイル.pdf');
    });

    test('handles extra whitespace in content', () {
      const content = '📎 File:   /data/output/file.pdf   ';
      final filePath = content.replaceFirst('📎 File: ', '').trim();
      expect(filePath, '/data/output/file.pdf');
    });

    test('prefix detection is case-sensitive', () {
      expect('📎 File: /path'.startsWith('📎 File:'), isTrue);
      expect('📎 file: /path'.startsWith('📎 File:'), isFalse);
      expect('📎File: /path'.startsWith('📎 File:'), isFalse);
      expect('File: /path'.startsWith('📎 File:'), isFalse);
    });

    test('empty path after prefix', () {
      const content = '📎 File: ';
      final filePath = content.replaceFirst('📎 File: ', '').trim();
      expect(filePath, '');
      final fileName = filePath.split('/').last;
      expect(fileName, '');
    });

    test('path with multiple consecutive slashes', () {
      const filePath = '/data//user///file.pdf';
      final fileName = filePath.split('/').last;
      expect(fileName, 'file.pdf');
    });

    test('path with dot-dot segments', () {
      const filePath = '/data/user/../output/file.pdf';
      final fileName = filePath.split('/').last;
      expect(fileName, 'file.pdf');
    });
  });
}
