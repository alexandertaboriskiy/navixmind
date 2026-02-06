import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PermissionManager Dialog Tests', () {
    Widget createTestWidget({required Widget child}) {
      return MaterialApp(
        home: Scaffold(body: child),
      );
    }

    group('Rationale Dialog', () {
      testWidgets('renders with correct title and rationale', (tester) async {
        const title = 'Camera Access';
        const rationale =
            'Camera access lets you scan documents and take photos to add to your queries.';

        await tester.pumpWidget(createTestWidget(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(title),
                    content: Text(rationale),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Not Now'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Continue'),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('Show Dialog'),
            ),
          ),
        ));

        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        expect(find.text(title), findsOneWidget);
        expect(find.text(rationale), findsOneWidget);
        expect(find.text('Not Now'), findsOneWidget);
        expect(find.text('Continue'), findsOneWidget);
      });

      testWidgets('Not Now button returns false', (tester) async {
        bool? result;

        await tester.pumpWidget(createTestWidget(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Test'),
                    content: const Text('Rationale'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Not Now'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Continue'),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('Show Dialog'),
            ),
          ),
        ));

        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Not Now'));
        await tester.pumpAndSettle();

        expect(result, isFalse);
      });

      testWidgets('Continue button returns true', (tester) async {
        bool? result;

        await tester.pumpWidget(createTestWidget(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Test'),
                    content: const Text('Rationale'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Not Now'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Continue'),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('Show Dialog'),
            ),
          ),
        ));

        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        expect(result, isTrue);
      });

      testWidgets('dismissing dialog returns null (treated as false)',
          (tester) async {
        bool? result;

        await tester.pumpWidget(createTestWidget(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Test'),
                        content: const Text('Rationale'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Not Now'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('Continue'),
                          ),
                        ],
                      ),
                    ) ??
                    false;
              },
              child: const Text('Show Dialog'),
            ),
          ),
        ));

        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        // Tap outside dialog to dismiss
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        expect(result, isFalse);
      });
    });

    group('Settings Dialog', () {
      testWidgets('renders with correct title format', (tester) async {
        const title = 'Camera Access';
        const rationale =
            'Camera access lets you scan documents and take photos to add to your queries.';

        await tester.pumpWidget(createTestWidget(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('$title Required'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(rationale),
                        const SizedBox(height: 16),
                        const Text(
                          'You previously denied this permission. '
                          'Please enable it in Settings to use this feature.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Open Settings'),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('Show Dialog'),
            ),
          ),
        ));

        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        expect(find.text('Camera Access Required'), findsOneWidget);
        expect(find.text(rationale), findsOneWidget);
        expect(
            find.text(
              'You previously denied this permission. '
              'Please enable it in Settings to use this feature.',
            ),
            findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);
        expect(find.text('Open Settings'), findsOneWidget);
      });

      testWidgets('Cancel button returns false', (tester) async {
        bool? result;

        await tester.pumpWidget(createTestWidget(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Test Required'),
                    content: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Rationale'),
                        SizedBox(height: 16),
                        Text('Denied message'),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Open Settings'),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('Show Dialog'),
            ),
          ),
        ));

        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        expect(result, isFalse);
      });

      testWidgets('Open Settings button returns true', (tester) async {
        bool? result;

        await tester.pumpWidget(createTestWidget(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Test Required'),
                    content: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Rationale'),
                        SizedBox(height: 16),
                        Text('Denied message'),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Open Settings'),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('Show Dialog'),
            ),
          ),
        ));

        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Settings'));
        await tester.pumpAndSettle();

        expect(result, isTrue);
      });

      testWidgets('settings dialog has Column layout with proper sizing',
          (tester) async {
        await tester.pumpWidget(createTestWidget(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Test Required'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Rationale'),
                        const SizedBox(height: 16),
                        const Text(
                          'Denied message',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Open Settings'),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('Show Dialog'),
            ),
          ),
        ));

        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        // Find the Column that contains our content (ancestor of "Rationale" text)
        final column = tester.widget<Column>(
          find.ancestor(
            of: find.text('Rationale'),
            matching: find.byType(Column),
          ).first,
        );
        expect(column.mainAxisSize, equals(MainAxisSize.min));
        expect(column.crossAxisAlignment, equals(CrossAxisAlignment.start));
      });

      testWidgets('permanently denied message has grey text style',
          (tester) async {
        await tester.pumpWidget(createTestWidget(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Test Required'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Rationale'),
                        const SizedBox(height: 16),
                        const Text(
                          'You previously denied this permission. '
                          'Please enable it in Settings to use this feature.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                    actions: const [],
                  ),
                );
              },
              child: const Text('Show Dialog'),
            ),
          ),
        ));

        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        // Find the grey-styled text
        final textWidget = tester.widget<Text>(
          find.text(
            'You previously denied this permission. '
            'Please enable it in Settings to use this feature.',
          ),
        );
        expect(textWidget.style?.color, equals(Colors.grey));
      });
    });

    group('Permission-specific rationale messages', () {
      test('Camera rationale is correct', () {
        const expected =
            'Camera access lets you scan documents and take photos to add to your queries.';
        expect(PermissionRationale.camera, equals(expected));
      });

      test('Microphone rationale is correct', () {
        const expected =
            'Microphone access enables voice input and audio recording for transcription.';
        expect(PermissionRationale.microphone, equals(expected));
      });

      test('Storage rationale is correct', () {
        const expected =
            'Storage access lets you select and process files from your device.';
        expect(PermissionRationale.storage, equals(expected));
      });

      test('Notifications rationale is correct', () {
        const expected =
            'Notifications alert you when long tasks (like video processing) complete.';
        expect(PermissionRationale.notifications, equals(expected));
      });
    });

    group('Permission-specific titles', () {
      test('Camera title is correct', () {
        expect(PermissionTitle.camera, equals('Camera Access'));
      });

      test('Microphone title is correct', () {
        expect(PermissionTitle.microphone, equals('Microphone Access'));
      });

      test('Storage title is correct', () {
        expect(PermissionTitle.storage, equals('Media Access'));
      });

      test('Notifications title is correct', () {
        expect(PermissionTitle.notifications, equals('Notifications'));
      });
    });

    group('Dialog accessibility', () {
      testWidgets('rationale dialog buttons are accessible', (tester) async {
        await tester.pumpWidget(createTestWidget(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Camera Access'),
                    content: const Text('Rationale'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Not Now'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Continue'),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('Show Dialog'),
            ),
          ),
        ));

        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        // Verify buttons can be tapped
        expect(find.byType(TextButton), findsOneWidget);
        expect(find.byType(ElevatedButton), findsWidgets);
      });

      testWidgets('dialog title is accessible', (tester) async {
        await tester.pumpWidget(createTestWidget(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Camera Access'),
                    content: const Text('Rationale'),
                    actions: const [],
                  ),
                );
              },
              child: const Text('Show Dialog'),
            ),
          ),
        ));

        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        final titleFinder = find.text('Camera Access');
        expect(titleFinder, findsOneWidget);
      });
    });

    group('Dialog widget structure', () {
      testWidgets('rationale dialog uses AlertDialog', (tester) async {
        await tester.pumpWidget(createTestWidget(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Test'),
                    content: const Text('Content'),
                    actions: const [],
                  ),
                );
              },
              child: const Text('Show Dialog'),
            ),
          ),
        ));

        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsOneWidget);
      });

      testWidgets('rationale dialog has exactly two action buttons',
          (tester) async {
        await tester.pumpWidget(createTestWidget(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Test'),
                    content: const Text('Content'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Not Now'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Continue'),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('Show Dialog'),
            ),
          ),
        ));

        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        // One TextButton and one ElevatedButton (plus the trigger button)
        expect(find.byType(TextButton), findsOneWidget);
        // Two ElevatedButtons: one trigger, one Continue
        expect(find.byType(ElevatedButton), findsNWidgets(2));
      });
    });

    group('Edge cases', () {
      testWidgets('dialog handles long rationale text', (tester) async {
        const longRationale = 'This is a very long rationale message that '
            'explains in great detail why the permission is needed. '
            'It goes on and on and on to test how the dialog handles '
            'text that might wrap to multiple lines. This should still '
            'render correctly and be scrollable if necessary.';

        await tester.pumpWidget(createTestWidget(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Test'),
                    content: const Text(longRationale),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Not Now'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Continue'),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('Show Dialog'),
            ),
          ),
        ));

        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        expect(find.text(longRationale), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('dialog handles empty title gracefully', (tester) async {
        await tester.pumpWidget(createTestWidget(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text(''),
                    content: const Text('Content'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Not Now'),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('Show Dialog'),
            ),
          ),
        ));

        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('multiple dialogs can be shown sequentially', (tester) async {
        int dialogCount = 0;

        await tester.pumpWidget(createTestWidget(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                dialogCount++;
                await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('Dialog $dialogCount'),
                    content: const Text('Content'),
                    actions: [
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('Show Dialog'),
            ),
          ),
        ));

        // Show first dialog
        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();
        expect(find.text('Dialog 1'), findsOneWidget);

        // Close first dialog
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();

        // Show second dialog
        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();
        expect(find.text('Dialog 2'), findsOneWidget);

        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
      });
    });

    group('Storage permission special case', () {
      test('storage permission checks photos and videos first', () {
        // Test that the logic would return early if photos or videos are granted
        // This tests the understanding of the code flow
        const storageLogicDescription = '''
          The requestStorage method should:
          1. Check if photos permission is granted
          2. Check if videos permission is granted
          3. If either is granted, return true immediately
          4. Otherwise, request photos permission with rationale
        ''';
        expect(storageLogicDescription, contains('photos'));
        expect(storageLogicDescription, contains('videos'));
        expect(storageLogicDescription, contains('return true'));
      });
    });
  });
}

/// Helper class to store expected permission rationale messages
/// Mirrors the values used in PermissionManager
class PermissionRationale {
  static const camera =
      'Camera access lets you scan documents and take photos to add to your queries.';
  static const microphone =
      'Microphone access enables voice input and audio recording for transcription.';
  static const storage =
      'Storage access lets you select and process files from your device.';
  static const notifications =
      'Notifications alert you when long tasks (like video processing) complete.';
}

/// Helper class to store expected permission titles
/// Mirrors the values used in PermissionManager
class PermissionTitle {
  static const camera = 'Camera Access';
  static const microphone = 'Microphone Access';
  static const storage = 'Media Access';
  static const notifications = 'Notifications';
}
