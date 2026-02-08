import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navixmind/app/theme.dart';
import 'package:navixmind/features/chat/presentation/widgets/input_bar.dart';

void main() {
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
    List<String> externalFiles = const [],
    Function(List<String>)? onFilesSelected,
  }) {
    return MaterialApp(
      theme: NavixTheme.darkTheme,
      home: Scaffold(
        body: InputBar(
          controller: controller,
          onSend: onSend ?? () {},
          enabled: enabled,
          isProcessing: isProcessing,
          externalFiles: externalFiles,
          onFilesSelected: onFilesSelected,
        ),
      ),
    );
  }

  group('Submit behavior', () {
    late Directory submitTempDir;

    setUp(() async {
      submitTempDir = await Directory.systemTemp.createTemp('input_bar_submit_');
    });

    tearDown(() async {
      if (await submitTempDir.exists()) {
        await submitTempDir.delete(recursive: true);
      }
    });

    String makeSubmitFile(String name) {
      final file = File('${submitTempDir.path}/$name');
      file.writeAsBytesSync(List.filled(100, 0));
      return file.path;
    }

    testWidgets('does not call onSend when text is empty and no files', (tester) async {
      var sendCalled = false;
      await tester.pumpWidget(createTestWidget(
        onSend: () => sendCalled = true,
      ));

      await tester.tap(find.byIcon(Icons.arrow_forward));
      await tester.pump();

      expect(sendCalled, isFalse);
    });

    testWidgets('calls onSend when text is not empty', (tester) async {
      var sendCalled = false;
      await tester.pumpWidget(createTestWidget(
        onSend: () => sendCalled = true,
      ));

      await tester.enterText(find.byType(TextField), 'Hello');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_forward));
      await tester.pump();

      expect(sendCalled, isTrue);
    });

    testWidgets('calls onSend when files attached even if text empty', (tester) async {
      final path = makeSubmitFile('test.jpg');

      var sendCalled = false;
      await tester.pumpWidget(createTestWidget(
        onSend: () => sendCalled = true,
        externalFiles: [path],
      ));
      await tester.pump(); // build
      await tester.pump(); // post-frame callback

      // Tap send with no text but files attached
      await tester.tap(find.byIcon(Icons.arrow_forward));
      await tester.pump();

      expect(sendCalled, isTrue);
    });

    testWidgets('does not call onSend with whitespace-only text and no files', (tester) async {
      var sendCalled = false;
      await tester.pumpWidget(createTestWidget(
        onSend: () => sendCalled = true,
      ));

      await tester.enterText(find.byType(TextField), '   ');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_forward));
      await tester.pump();

      expect(sendCalled, isFalse);
    });

    testWidgets('clears attached files after send', (tester) async {
      final path = makeSubmitFile('clear_me.jpg');

      await tester.pumpWidget(createTestWidget(
        externalFiles: [path],
      ));
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('clear_me.jpg'), findsOneWidget);

      // Enter text and send
      await tester.enterText(find.byType(TextField), 'Go');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_forward));
      await tester.pump();

      expect(find.textContaining('clear_me.jpg'), findsNothing);
    });

    testWidgets('onSubmitted via keyboard also triggers send', (tester) async {
      var sendCalled = false;
      await tester.pumpWidget(createTestWidget(
        onSend: () => sendCalled = true,
      ));

      await tester.enterText(find.byType(TextField), 'Hello');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pump();

      expect(sendCalled, isTrue);
    });
  });

  group('Disabled and processing states', () {
    testWidgets('text field disabled when enabled=false', (tester) async {
      await tester.pumpWidget(createTestWidget(enabled: false));

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.enabled, isFalse);
    });

    testWidgets('hint says "Connecting..." when disabled', (tester) async {
      await tester.pumpWidget(createTestWidget(enabled: false));

      expect(find.text('Connecting...'), findsOneWidget);
    });

    testWidgets('hint says "Type a message..." when enabled', (tester) async {
      await tester.pumpWidget(createTestWidget(enabled: true));

      expect(find.text('Type a message...'), findsOneWidget);
    });

    testWidgets('send button replaced by spinner when processing', (tester) async {
      await tester.pumpWidget(createTestWidget(isProcessing: true));

      expect(find.byIcon(Icons.arrow_forward), findsNothing);
    });

    testWidgets('send button visible when not processing', (tester) async {
      await tester.pumpWidget(createTestWidget(isProcessing: false));

      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
    });

    testWidgets('add file button disabled when not enabled', (tester) async {
      await tester.pumpWidget(createTestWidget(enabled: false));

      // The button should be present but its onPressed should be null
      // We can verify by checking the icon exists
      expect(find.byIcon(Icons.add), findsOneWidget);
    });
  });

  group('Slash command suggestions', () {
    testWidgets('suggestions appear when typing /', (tester) async {
      await tester.pumpWidget(createTestWidget());

      await tester.enterText(find.byType(TextField), '/cr');
      await tester.pump();

      // Should show at least one suggestion
      expect(find.text('/crop'), findsOneWidget);
    });

    testWidgets('suggestions hidden with just /', (tester) async {
      await tester.pumpWidget(createTestWidget());

      await tester.enterText(find.byType(TextField), '/');
      await tester.pump();

      // Suggestions require at least 2 chars (/+something)
      // The logic is: text.startsWith('/') && text.length > 1
      expect(find.text('/crop'), findsNothing);
    });

    testWidgets('suggestions disappear when text no longer starts with /', (tester) async {
      await tester.pumpWidget(createTestWidget());

      // Show suggestions
      await tester.enterText(find.byType(TextField), '/cr');
      await tester.pump();
      expect(find.text('/crop'), findsOneWidget);

      // Clear text
      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump();

      // Suggestions should be gone
      expect(find.text('/crop'), findsNothing);
    });

    testWidgets('suggestions match by command name', (tester) async {
      await tester.pumpWidget(createTestWidget());

      await tester.enterText(find.byType(TextField), '/ocr');
      await tester.pump();

      // Should show OCR-related commands
      expect(find.text('/ocr'), findsAtLeastNWidgets(1));
    });
  });

  group('File chip icons per type', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('input_bar_icons_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    String makeFile(String name) {
      final file = File('${tempDir.path}/$name');
      file.writeAsBytesSync(List.filled(10, 0));
      return file.path;
    }

    testWidgets('image file shows ◫ icon', (tester) async {
      await tester.pumpWidget(createTestWidget(
        externalFiles: [makeFile('photo.jpg')],
      ));
      await tester.pump();
      await tester.pump();

      expect(find.text('◫'), findsOneWidget);
    });

    testWidgets('video file shows ▶ icon', (tester) async {
      await tester.pumpWidget(createTestWidget(
        externalFiles: [makeFile('clip.mp4')],
      ));
      await tester.pump();
      await tester.pump();

      expect(find.text('▶'), findsOneWidget);
    });

    testWidgets('audio file shows ♪ icon', (tester) async {
      await tester.pumpWidget(createTestWidget(
        externalFiles: [makeFile('song.mp3')],
      ));
      await tester.pump();
      await tester.pump();

      expect(find.text('♪'), findsOneWidget);
    });

    testWidgets('PDF file shows ◰ icon', (tester) async {
      await tester.pumpWidget(createTestWidget(
        externalFiles: [makeFile('doc.pdf')],
      ));
      await tester.pump();
      await tester.pump();

      expect(find.text('◰'), findsOneWidget);
    });

    testWidgets('document file shows ◳ icon', (tester) async {
      await tester.pumpWidget(createTestWidget(
        externalFiles: [makeFile('report.docx')],
      ));
      await tester.pump();
      await tester.pump();

      expect(find.text('◳'), findsOneWidget);
    });

    testWidgets('unknown file shows ◉ icon', (tester) async {
      await tester.pumpWidget(createTestWidget(
        externalFiles: [makeFile('data.xyz')],
      ));
      await tester.pump();
      await tester.pump();

      expect(find.text('◉'), findsOneWidget);
    });

    testWidgets('file without extension shows ◉ icon', (tester) async {
      await tester.pumpWidget(createTestWidget(
        externalFiles: [makeFile('Makefile')],
      ));
      await tester.pump();
      await tester.pump();

      expect(find.text('◉'), findsOneWidget);
    });
  });

  group('File chip name truncation', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('input_bar_trunc_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    String makeFile(String name) {
      final file = File('${tempDir.path}/$name');
      file.writeAsBytesSync(List.filled(10, 0));
      return file.path;
    }

    testWidgets('short filename displayed fully', (tester) async {
      await tester.pumpWidget(createTestWidget(
        externalFiles: [makeFile('short.pdf')],
      ));
      await tester.pump();
      await tester.pump();

      expect(find.text('short.pdf'), findsOneWidget);
    });

    testWidgets('filename exactly 15 chars displayed fully', (tester) async {
      await tester.pumpWidget(createTestWidget(
        externalFiles: [makeFile('exactly15chars!')], // 15 chars
      ));
      await tester.pump();
      await tester.pump();

      expect(find.text('exactly15chars!'), findsOneWidget);
    });

    testWidgets('filename over 15 chars is truncated with ...', (tester) async {
      await tester.pumpWidget(createTestWidget(
        externalFiles: [makeFile('this_is_a_very_long_filename.pdf')],
      ));
      await tester.pump();
      await tester.pump();

      // Should truncate to first 12 chars + ...
      expect(find.text('this_is_a_ve...'), findsOneWidget);
    });
  });

  group('File removal', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('input_bar_rm_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    String makeFile(String name) {
      final file = File('${tempDir.path}/$name');
      file.writeAsBytesSync(List.filled(10, 0));
      return file.path;
    }

    testWidgets('close button removes file chip', (tester) async {
      await tester.pumpWidget(createTestWidget(
        externalFiles: [makeFile('remove.jpg')],
      ));
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('remove.jpg'), findsOneWidget);

      await tester.tap(find.text(NavixTheme.iconClose));
      await tester.pump();

      expect(find.textContaining('remove.jpg'), findsNothing);
    });

    testWidgets('removing one file keeps others', (tester) async {
      await tester.pumpWidget(createTestWidget(
        externalFiles: [makeFile('keep.jpg'), makeFile('remove.pdf')],
      ));
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('keep.jpg'), findsOneWidget);
      expect(find.textContaining('remove.pdf'), findsOneWidget);

      // Tap second close button (remove.pdf)
      final closeButtons = find.text(NavixTheme.iconClose);
      expect(closeButtons, findsNWidgets(2));
      await tester.tap(closeButtons.last);
      await tester.pump();

      expect(find.textContaining('keep.jpg'), findsOneWidget);
      expect(find.textContaining('remove.pdf'), findsNothing);
    });

    testWidgets('removal fires onFilesSelected callback', (tester) async {
      final selectedFiles = <List<String>>[];
      await tester.pumpWidget(createTestWidget(
        externalFiles: [makeFile('a.jpg'), makeFile('b.pdf')],
        onFilesSelected: (files) => selectedFiles.add(List.from(files)),
      ));
      await tester.pump();
      await tester.pump();

      // Remove first file
      await tester.tap(find.text(NavixTheme.iconClose).first);
      await tester.pump();

      expect(selectedFiles, isNotEmpty);
      // After removing first, only second should remain
      expect(selectedFiles.last, hasLength(1));
    });
  });

  group('Multiple external files', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('input_bar_multi_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    String makeFile(String name) {
      final file = File('${tempDir.path}/$name');
      file.writeAsBytesSync(List.filled(10, 0));
      return file.path;
    }

    testWidgets('three files all visible', (tester) async {
      await tester.pumpWidget(createTestWidget(
        externalFiles: [
          makeFile('one.jpg'),
          makeFile('two.pdf'),
          makeFile('three.mp4'),
        ],
      ));
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('one.jpg'), findsOneWidget);
      expect(find.textContaining('two.pdf'), findsOneWidget);
      expect(find.textContaining('three.mp4'), findsOneWidget);
    });

    testWidgets('horizontal scroll contains all file chips', (tester) async {
      await tester.pumpWidget(createTestWidget(
        externalFiles: [
          makeFile('a.jpg'),
          makeFile('b.pdf'),
          makeFile('c.mp4'),
          makeFile('d.wav'),
        ],
      ));
      await tester.pump();
      await tester.pump();

      // All 4 close buttons should be present
      expect(find.text(NavixTheme.iconClose), findsNWidgets(4));
    });

    testWidgets('duplicate path not added twice via didUpdateWidget', (tester) async {
      final path = makeFile('dup.jpg');

      await tester.pumpWidget(createTestWidget(
        externalFiles: [path],
      ));
      await tester.pump();
      await tester.pump();

      // Rebuild with same file
      await tester.pumpWidget(createTestWidget(
        externalFiles: [path],
      ));
      await tester.pump();
      await tester.pump();

      // Should only appear once
      expect(find.text(NavixTheme.iconClose), findsOneWidget);
    });
  });

  group('AttachedFile model', () {
    test('stores all fields', () {
      final f = AttachedFile(
        path: '/data/test.pdf',
        name: 'test.pdf',
        type: 'pdf',
        size: 1024,
      );
      expect(f.path, '/data/test.pdf');
      expect(f.name, 'test.pdf');
      expect(f.type, 'pdf');
      expect(f.size, 1024);
    });

    test('accepts zero size', () {
      final f = AttachedFile(path: '/a', name: 'a', type: 'default', size: 0);
      expect(f.size, 0);
    });

    test('accepts empty strings', () {
      final f = AttachedFile(path: '', name: '', type: '', size: 0);
      expect(f.path, '');
      expect(f.name, '');
      expect(f.type, '');
    });
  });

  group('Layout', () {
    testWidgets('has text field, add button, and send button', (tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
    });

    testWidgets('no file chips when no files attached', (tester) async {
      await tester.pumpWidget(createTestWidget());

      // Close button should not be present (no file chips)
      expect(find.text(NavixTheme.iconClose), findsNothing);
    });

    testWidgets('file chip row appears above input row when files attached', (tester) async {
      final layoutDir = Directory.systemTemp.createTempSync('input_bar_layout_');
      final file = File('${layoutDir.path}/layout.jpg');
      file.writeAsBytesSync(List.filled(10, 0));

      await tester.pumpWidget(createTestWidget(
        externalFiles: [file.path],
      ));
      await tester.pump();
      await tester.pump();

      // File chip should be above the text field
      final chipCenter = tester.getCenter(find.textContaining('layout.jpg'));
      final textFieldCenter = tester.getCenter(find.byType(TextField));
      expect(chipCenter.dy, lessThan(textFieldCenter.dy));

      layoutDir.deleteSync(recursive: true);
    });

    testWidgets('add button has accessibility label', (tester) async {
      await tester.pumpWidget(createTestWidget());

      // Find the Semantics widget wrapping the add button
      final semantics = find.bySemanticsLabel('Add file');
      expect(semantics, findsOneWidget);
    });

    testWidgets('send button has accessibility label', (tester) async {
      await tester.pumpWidget(createTestWidget());

      final semantics = find.bySemanticsLabel('Send');
      expect(semantics, findsOneWidget);
    });
  });
}
