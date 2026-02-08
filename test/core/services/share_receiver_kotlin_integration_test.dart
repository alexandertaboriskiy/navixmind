import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navixmind/core/services/share_receiver_service.dart';

/// Tests validating the Dart-side contract assumptions about data coming
/// from the Kotlin (MainActivity.kt) share intent handler.
///
/// These tests verify that the Dart service correctly handles the exact
/// data shapes and patterns that Kotlin sends, as documented in the
/// Kotlin implementation.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ShareReceiverService service;

  setUp(() {
    service = ShareReceiverService.forTest();
  });

  tearDown(() {
    service.dispose();
  });

  Future<void> simulateKotlinCall(dynamic arguments) async {
    await service.handleMethodCall(MethodCall('onFilesShared', arguments));
  }

  group('Kotlin data shapes', () {
    test('standard successful file share from Kotlin', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      // This is the exact shape Kotlin sends for a successful file copy
      await simulateKotlinCall({
        'files': [
          {
            'path': '/data/user/0/ai.navixmind/files/navixmind_shared/photo.jpg',
            'name': 'photo.jpg',
            'size': 2458624, // typical photo size
            'error': null,
          },
        ],
        'text': null,
      });
      await Future.delayed(Duration.zero);

      expect(events, hasLength(1));
      final file = events[0].files[0];
      expect(file.path, startsWith('/data/user/0/ai.navixmind'));
      expect(file.path, contains('navixmind_shared'));
      expect(file.name, 'photo.jpg');
      expect(file.size, 2458624);
      expect(file.error, isNull);
    });

    test('Kotlin size limit error format', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      // Kotlin formats: "${filename} is too large (${formatSize(fileSize)}). Max: ${limitMB}MB"
      await simulateKotlinCall({
        'files': [
          {
            'path': '',
            'name': 'huge_video.mp4',
            'size': 629145600, // 600MB
            'error': 'huge_video.mp4 is too large (600 MB). Max: 500MB',
          },
        ],
        'text': null,
      });
      await Future.delayed(Duration.zero);

      expect(events[0].files[0].error, contains('too large'));
      expect(events[0].files[0].error, contains('500MB'));
      expect(events[0].files[0].path, ''); // empty when error
    });

    test('Kotlin "could not read" error format', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      // Kotlin sends: "Could not read file: $filename"
      await simulateKotlinCall({
        'files': [
          {
            'path': '',
            'name': 'locked.pdf',
            'size': 0,
            'error': 'Could not read file: locked.pdf',
          },
        ],
        'text': null,
      });
      await Future.delayed(Duration.zero);

      expect(events[0].files[0].error, 'Could not read file: locked.pdf');
    });

    test('Kotlin exception error format', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      // Kotlin sends: "Failed to process file: ${e.message}"
      await simulateKotlinCall({
        'files': [
          {
            'path': '',
            'name': 'corrupt.dat',
            'size': 0,
            'error': 'Failed to process file: java.io.IOException: Permission denied',
          },
        ],
        'text': null,
      });
      await Future.delayed(Duration.zero);

      expect(events[0].files[0].error, contains('Failed to process'));
      expect(events[0].files[0].error, contains('Permission denied'));
    });
  });

  group('Kotlin filename deduplication patterns', () {
    test('deduplicated filename with _1 suffix', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      // Kotlin deduplicates: "photo_1.jpg" when "photo.jpg" already exists
      await simulateKotlinCall({
        'files': [
          {
            'path': '/data/user/0/ai.navixmind/files/navixmind_shared/photo.jpg',
            'name': 'photo.jpg',
            'size': 1000,
            'error': null,
          },
          {
            'path': '/data/user/0/ai.navixmind/files/navixmind_shared/photo_1.jpg',
            'name': 'photo_1.jpg',
            'size': 2000,
            'error': null,
          },
        ],
        'text': null,
      });
      await Future.delayed(Duration.zero);

      expect(events[0].files[0].name, 'photo.jpg');
      expect(events[0].files[1].name, 'photo_1.jpg');
    });

    test('multiple deduplication suffixes', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      await simulateKotlinCall({
        'files': [
          {'path': '/data/shared/doc.pdf', 'name': 'doc.pdf', 'size': 100, 'error': null},
          {'path': '/data/shared/doc_1.pdf', 'name': 'doc_1.pdf', 'size': 200, 'error': null},
          {'path': '/data/shared/doc_2.pdf', 'name': 'doc_2.pdf', 'size': 300, 'error': null},
        ],
        'text': null,
      });
      await Future.delayed(Duration.zero);

      expect(events[0].files.map((f) => f.name).toList(),
          ['doc.pdf', 'doc_1.pdf', 'doc_2.pdf']);
    });

    test('fallback filename when display name unavailable', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      // Kotlin fallback: "shared_${System.currentTimeMillis()}.dat"
      await simulateKotlinCall({
        'files': [
          {
            'path': '/data/shared/shared_1705318200000.dat',
            'name': 'shared_1705318200000.dat',
            'size': 500,
            'error': null,
          },
        ],
        'text': null,
      });
      await Future.delayed(Duration.zero);

      expect(events[0].files[0].name, startsWith('shared_'));
      expect(events[0].files[0].name, endsWith('.dat'));
    });
  });

  group('Kotlin ACTION_SEND vs ACTION_SEND_MULTIPLE', () {
    test('ACTION_SEND: single file', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      await simulateKotlinCall({
        'files': [
          {
            'path': '/data/shared/single.jpg',
            'name': 'single.jpg',
            'size': 1024,
            'error': null,
          },
        ],
        'text': null,
      });
      await Future.delayed(Duration.zero);

      expect(events[0].files, hasLength(1));
    });

    test('ACTION_SEND_MULTIPLE: multiple files', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      await simulateKotlinCall({
        'files': [
          {'path': '/data/shared/img1.jpg', 'name': 'img1.jpg', 'size': 100, 'error': null},
          {'path': '/data/shared/img2.jpg', 'name': 'img2.jpg', 'size': 200, 'error': null},
          {'path': '/data/shared/img3.jpg', 'name': 'img3.jpg', 'size': 300, 'error': null},
        ],
        'text': null,
      });
      await Future.delayed(Duration.zero);

      expect(events[0].files, hasLength(3));
    });

    test('ACTION_SEND with EXTRA_TEXT (browser share)', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      // Chrome shares URL as EXTRA_TEXT alongside EXTRA_STREAM
      await simulateKotlinCall({
        'files': [],
        'text': 'https://www.example.com/article/12345',
      });
      await Future.delayed(Duration.zero);

      expect(events[0].files, isEmpty);
      expect(events[0].text, startsWith('https://'));
    });

    test('ACTION_SEND with both file and text', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      // Some apps share a file + descriptive text
      await simulateKotlinCall({
        'files': [
          {
            'path': '/data/shared/screenshot.png',
            'name': 'screenshot.png',
            'size': 50000,
            'error': null,
          },
        ],
        'text': 'Check out this screenshot!',
      });
      await Future.delayed(Duration.zero);

      expect(events[0].files, hasLength(1));
      expect(events[0].text, 'Check out this screenshot!');
    });
  });

  group('Kotlin file path patterns', () {
    test('internal storage path', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      await simulateKotlinCall({
        'files': [
          {
            'path': '/data/user/0/ai.navixmind/files/navixmind_shared/test.pdf',
            'name': 'test.pdf',
            'size': 1024,
            'error': null,
          },
        ],
        'text': null,
      });
      await Future.delayed(Duration.zero);

      expect(events[0].files[0].path, contains('/data/user/0/ai.navixmind'));
    });

    test('alternative internal storage path', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      // Some devices use /data/data/ instead of /data/user/0/
      await simulateKotlinCall({
        'files': [
          {
            'path': '/data/data/ai.navixmind/files/navixmind_shared/test.pdf',
            'name': 'test.pdf',
            'size': 1024,
            'error': null,
          },
        ],
        'text': null,
      });
      await Future.delayed(Duration.zero);

      expect(events[0].files[0].path, contains('/data/data/ai.navixmind'));
    });
  });

  group('Kotlin size formats', () {
    test('Kotlin sends size as Long (large int)', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      // Kotlin Long → Platform channel int
      await simulateKotlinCall({
        'files': [
          {
            'path': '/data/shared/big.mp4',
            'name': 'big.mp4',
            'size': 524288000, // exactly 500MB
            'error': null,
          },
        ],
        'text': null,
      });
      await Future.delayed(Duration.zero);

      expect(events[0].files[0].size, 524288000);
    });

    test('zero-byte file from Kotlin', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      await simulateKotlinCall({
        'files': [
          {
            'path': '/data/shared/empty.txt',
            'name': 'empty.txt',
            'size': 0,
            'error': null,
          },
        ],
        'text': null,
      });
      await Future.delayed(Duration.zero);

      expect(events[0].files[0].size, 0);
    });

    test('error file size from Kotlin (stored even for errors)', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      // Kotlin stores the file size even for error files
      await simulateKotlinCall({
        'files': [
          {
            'path': '',
            'name': 'oversized.mp4',
            'size': 629145600, // 600MB
            'error': 'oversized.mp4 is too large (600 MB). Max: 500MB',
          },
        ],
        'text': null,
      });
      await Future.delayed(Duration.zero);

      expect(events[0].files[0].size, 629145600);
      expect(events[0].files[0].error, isNotNull);
    });
  });

  group('Kotlin cold start buffering', () {
    test('Kotlin sends before Flutter engine ready: buffered in pendingShareData', () async {
      // Simulate: Kotlin sent data, then Flutter mounts and checks pending
      await service.handleMethodCall(MethodCall('onFilesShared', {
        'files': [
          {
            'path': '/data/shared/cold_start.jpg',
            'name': 'cold_start.jpg',
            'size': 1024,
            'error': null,
          },
        ],
        'text': 'Shared from Gallery',
      }));

      // No listener yet — should be buffered
      expect(service.consumePending(), isNotNull);
    });

    test('Kotlin onNewIntent (warm start) delivers to stream', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      // App was already running, share intent comes via onNewIntent
      await service.handleMethodCall(MethodCall('onFilesShared', {
        'files': [
          {
            'path': '/data/shared/warm_start.jpg',
            'name': 'warm_start.jpg',
            'size': 2048,
            'error': null,
          },
        ],
        'text': null,
      }));
      await Future.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events[0].files[0].name, 'warm_start.jpg');
    });
  });

  group('Kotlin cleanup expectations', () {
    test('files older than 24h are cleaned up by Kotlin — Dart handles any path', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      // Even if the file was supposed to be cleaned up,
      // Dart doesn't validate file existence — it just stores the path.
      // ChatScreen will handle File.exists() checks later.
      await simulateKotlinCall({
        'files': [
          {
            'path': '/data/shared/maybe_cleaned.jpg',
            'name': 'maybe_cleaned.jpg',
            'size': 100,
            'error': null,
          },
        ],
        'text': null,
      });
      await Future.delayed(Duration.zero);

      // Path is stored as-is, no validation at service level
      expect(events[0].files[0].path, '/data/shared/maybe_cleaned.jpg');
    });
  });

  group('Kotlin intent action clearing', () {
    test('duplicate event from config change should not happen (Kotlin clears action)', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      // In practice, Kotlin sets intent.action = null after processing.
      // But if somehow a duplicate arrives, Dart handles it fine.
      for (var i = 0; i < 3; i++) {
        await simulateKotlinCall({
          'files': [
            {'path': '/data/shared/dup.jpg', 'name': 'dup.jpg', 'size': 100, 'error': null},
          ],
          'text': null,
        });
      }
      await Future.delayed(Duration.zero);

      // All 3 are delivered — ChatScreen appends (no dedup at service level)
      expect(events, hasLength(3));
    });
  });

  group('Real-world share scenarios', () {
    test('Gallery: share single photo', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      await simulateKotlinCall({
        'files': [
          {
            'path': '/data/user/0/ai.navixmind/files/navixmind_shared/IMG_20250115_143022.jpg',
            'name': 'IMG_20250115_143022.jpg',
            'size': 3145728, // 3MB
            'error': null,
          },
        ],
        'text': null,
      });
      await Future.delayed(Duration.zero);

      expect(events[0].files[0].name, 'IMG_20250115_143022.jpg');
      expect(events[0].files[0].size, 3145728);
    });

    test('Gallery: share multiple photos', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      await simulateKotlinCall({
        'files': List.generate(5, (i) {
          return {
            'path': '/data/shared/IMG_$i.jpg',
            'name': 'IMG_$i.jpg',
            'size': (i + 1) * 1024 * 1024,
            'error': null,
          };
        }),
        'text': null,
      });
      await Future.delayed(Duration.zero);

      expect(events[0].files, hasLength(5));
    });

    test('Chrome: share webpage URL', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      await simulateKotlinCall({
        'files': [],
        'text': 'https://en.wikipedia.org/wiki/Artificial_intelligence',
      });
      await Future.delayed(Duration.zero);

      expect(events[0].files, isEmpty);
      expect(events[0].text, contains('wikipedia'));
    });

    test('Files app: share PDF document', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      await simulateKotlinCall({
        'files': [
          {
            'path': '/data/shared/Annual_Report_2025.pdf',
            'name': 'Annual_Report_2025.pdf',
            'size': 15728640, // 15MB
            'error': null,
          },
        ],
        'text': null,
      });
      await Future.delayed(Duration.zero);

      expect(events[0].files[0].name, 'Annual_Report_2025.pdf');
    });

    test('Mixed share: photos and one oversized video', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      await simulateKotlinCall({
        'files': [
          {
            'path': '/data/shared/photo1.jpg',
            'name': 'photo1.jpg',
            'size': 2048000,
            'error': null,
          },
          {
            'path': '/data/shared/photo2.jpg',
            'name': 'photo2.jpg',
            'size': 3072000,
            'error': null,
          },
          {
            'path': '',
            'name': 'huge_4k_video.mp4',
            'size': 629145600,
            'error': 'huge_4k_video.mp4 is too large (600 MB). Max: 500MB',
          },
        ],
        'text': null,
      });
      await Future.delayed(Duration.zero);

      final valid = events[0].files.where((f) => f.error == null).toList();
      final errors = events[0].files.where((f) => f.error != null).toList();
      expect(valid, hasLength(2));
      expect(errors, hasLength(1));
      expect(errors[0].name, 'huge_4k_video.mp4');
    });
  });
}
