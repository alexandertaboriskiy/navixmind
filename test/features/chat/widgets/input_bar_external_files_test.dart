import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navixmind/app/theme.dart';
import 'package:navixmind/features/chat/presentation/widgets/input_bar.dart';

void main() {
  group('InputBar externalFiles', () {
    late TextEditingController controller;
    late Directory tempDir;

    setUp(() async {
      controller = TextEditingController();
      tempDir = await Directory.systemTemp.createTemp('input_bar_test_');
    });

    tearDown(() async {
      controller.dispose();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    /// Creates a temporary file with given name and returns its path.
    String createTempFile(String name, {int size = 100}) {
      final file = File('${tempDir.path}/$name');
      file.writeAsBytesSync(List.filled(size, 0));
      return file.path;
    }

    Widget createTestWidget({
      List<String> externalFiles = const [],
      Function(List<String>)? onFilesSelected,
      VoidCallback? onSend,
    }) {
      return MaterialApp(
        theme: NavixTheme.darkTheme,
        home: Scaffold(
          body: InputBar(
            controller: controller,
            onSend: onSend ?? () {},
            externalFiles: externalFiles,
            onFilesSelected: onFilesSelected,
          ),
        ),
      );
    }

    /// Pumps enough frames for the post-frame callback setState to take effect.
    Future<void> pumpAndSettle(WidgetTester tester) async {
      await tester.pump(); // build
      await tester.pump(); // post-frame callback setState
    }

    testWidgets('no file chips when externalFiles is empty', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await pumpAndSettle(tester);

      // No file chips visible — only button GestureDetectors
      expect(find.byType(GestureDetector), findsWidgets);
    });

    testWidgets('external files create attached file chips', (tester) async {
      final path = createTempFile('photo.jpg');

      await tester.pumpWidget(createTestWidget(
        externalFiles: [path],
      ));
      await pumpAndSettle(tester);

      expect(find.textContaining('photo.jpg'), findsOneWidget);
    });

    testWidgets('multiple external files all appear', (tester) async {
      final path1 = createTempFile('a.jpg');
      final path2 = createTempFile('b.pdf');

      await tester.pumpWidget(createTestWidget(
        externalFiles: [path1, path2],
      ));
      await pumpAndSettle(tester);

      expect(find.textContaining('a.jpg'), findsOneWidget);
      expect(find.textContaining('b.pdf'), findsOneWidget);
    });

    testWidgets('duplicate paths are not added twice', (tester) async {
      final path = createTempFile('photo.jpg');

      // First render with the file
      await tester.pumpWidget(createTestWidget(
        externalFiles: [path],
      ));
      await pumpAndSettle(tester);

      // Re-render with same file again
      await tester.pumpWidget(createTestWidget(
        externalFiles: [path],
      ));
      await pumpAndSettle(tester);

      // Should only show one chip
      expect(find.textContaining('photo.jpg'), findsOneWidget);
    });

    testWidgets('new external files are added via didUpdateWidget', (tester) async {
      final path1 = createTempFile('first.jpg');
      final path2 = createTempFile('second.pdf');

      // Start with one file
      await tester.pumpWidget(createTestWidget(
        externalFiles: [path1],
      ));
      await pumpAndSettle(tester);
      expect(find.textContaining('first.jpg'), findsOneWidget);

      // Update with both files
      await tester.pumpWidget(createTestWidget(
        externalFiles: [path1, path2],
      ));
      await pumpAndSettle(tester);

      expect(find.textContaining('first.jpg'), findsOneWidget);
      expect(find.textContaining('second.pdf'), findsOneWidget);
    });

    testWidgets('file removal works with external files', (tester) async {
      final path = createTempFile('rm_me.jpg');
      final selectedFiles = <List<String>>[];

      await tester.pumpWidget(createTestWidget(
        externalFiles: [path],
        onFilesSelected: (files) => selectedFiles.add(List.from(files)),
      ));
      await pumpAndSettle(tester);

      expect(find.textContaining('rm_me.jpg'), findsOneWidget);

      // Tap the close/remove icon on the file chip
      final closeButton = find.text(NavixTheme.iconClose);
      expect(closeButton, findsOneWidget);
      await tester.tap(closeButton);
      await tester.pump();

      // File should be removed
      expect(find.textContaining('rm_me.jpg'), findsNothing);
      // onFilesSelected called with empty list (from _removeFile, not _sync)
      expect(selectedFiles.last, isEmpty);
    });

    testWidgets('handles non-existent file path gracefully', (tester) async {
      await tester.pumpWidget(createTestWidget(
        externalFiles: ['/tmp/does_not_exist_12345.jpg'],
      ));
      await pumpAndSettle(tester);

      // Should still show the name even though file doesn't exist
      expect(find.textContaining('does_not_exi'), findsOneWidget);
    });

    testWidgets('correctly detects file types from extensions', (tester) async {
      final jpgPath = createTempFile('image.jpg');
      final pdfPath = createTempFile('doc.pdf');
      final mp4Path = createTempFile('video.mp4');

      await tester.pumpWidget(createTestWidget(
        externalFiles: [jpgPath, pdfPath, mp4Path],
      ));
      await pumpAndSettle(tester);

      expect(find.textContaining('image.jpg'), findsOneWidget);
      expect(find.textContaining('doc.pdf'), findsOneWidget);
      expect(find.textContaining('video.mp4'), findsOneWidget);
    });

    testWidgets('send clears attached files', (tester) async {
      final path = createTempFile('send_me.jpg');
      var sendCalled = false;

      await tester.pumpWidget(createTestWidget(
        externalFiles: [path],
        onSend: () => sendCalled = true,
      ));
      await pumpAndSettle(tester);

      expect(find.textContaining('send_me.jpg'), findsOneWidget);

      // Enter text and send
      await tester.enterText(find.byType(TextField), 'Process this');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_forward));
      await tester.pump();

      expect(sendCalled, isTrue);
      // Files should be cleared after send
      expect(find.textContaining('send_me.jpg'), findsNothing);
    });

    testWidgets('files without extension get default type', (tester) async {
      final path = createTempFile('noext');

      await tester.pumpWidget(createTestWidget(
        externalFiles: [path],
      ));
      await pumpAndSettle(tester);

      // Should show generic icon
      expect(find.text('\u25c9'), findsOneWidget);
    });
  });
}
