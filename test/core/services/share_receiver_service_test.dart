import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navixmind/core/services/share_receiver_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ShareReceiverService service;

  setUp(() {
    service = ShareReceiverService.forTest();
  });

  tearDown(() {
    service.dispose();
  });

  /// Simulates Kotlin calling `onFilesShared` via the MethodChannel.
  Future<void> simulateCall(
    ShareReceiverService svc,
    String method,
    dynamic arguments,
  ) async {
    await svc.handleMethodCall(MethodCall(method, arguments));
  }

  group('ShareReceiverService', () {
    group('onFilesShared parsing', () {
      test('creates SharedFilesEvent with correct fields', () async {
        final events = <SharedFilesEvent>[];
        service.stream.listen(events.add);

        await simulateCall(service, 'onFilesShared', {
          'files': [
            {
              'path': '/data/shared/photo.jpg',
              'name': 'photo.jpg',
              'size': 1024,
              'error': null,
            },
          ],
          'text': null,
        });

        await Future.delayed(Duration.zero);
        expect(events, hasLength(1));
        expect(events[0].files, hasLength(1));
        expect(events[0].files[0].path, '/data/shared/photo.jpg');
        expect(events[0].files[0].name, 'photo.jpg');
        expect(events[0].files[0].size, 1024);
        expect(events[0].files[0].error, isNull);
        expect(events[0].text, isNull);
      });

      test('parses multiple files', () async {
        final events = <SharedFilesEvent>[];
        service.stream.listen(events.add);

        await simulateCall(service, 'onFilesShared', {
          'files': [
            {
              'path': '/data/shared/a.jpg',
              'name': 'a.jpg',
              'size': 100,
              'error': null,
            },
            {
              'path': '/data/shared/b.pdf',
              'name': 'b.pdf',
              'size': 200,
              'error': null,
            },
            {
              'path': '',
              'name': 'c.mp4',
              'size': 999999999,
              'error': 'c.mp4 is too large (953MB). Max: 500MB',
            },
          ],
          'text': 'Check these files',
        });

        await Future.delayed(Duration.zero);
        expect(events, hasLength(1));
        expect(events[0].files, hasLength(3));
        expect(events[0].files[0].name, 'a.jpg');
        expect(events[0].files[1].name, 'b.pdf');
        expect(events[0].files[2].error, contains('too large'));
        expect(events[0].text, 'Check these files');
      });

      test('parses text-only event (no files)', () async {
        final events = <SharedFilesEvent>[];
        service.stream.listen(events.add);

        await simulateCall(service, 'onFilesShared', {
          'files': [],
          'text': 'https://example.com/article',
        });

        await Future.delayed(Duration.zero);
        expect(events, hasLength(1));
        expect(events[0].files, isEmpty);
        expect(events[0].text, 'https://example.com/article');
      });

      test('handles null text field', () async {
        final events = <SharedFilesEvent>[];
        service.stream.listen(events.add);

        await simulateCall(service, 'onFilesShared', {
          'files': [
            {
              'path': '/data/shared/photo.jpg',
              'name': 'photo.jpg',
              'size': 512,
              'error': null,
            },
          ],
          'text': null,
        });

        await Future.delayed(Duration.zero);
        expect(events, hasLength(1));
        expect(events[0].text, isNull);
      });

      test('includes files with errors in event', () async {
        final events = <SharedFilesEvent>[];
        service.stream.listen(events.add);

        await simulateCall(service, 'onFilesShared', {
          'files': [
            {
              'path': '',
              'name': 'huge.mp4',
              'size': 0,
              'error': 'File too large',
            },
          ],
          'text': null,
        });

        await Future.delayed(Duration.zero);
        expect(events, hasLength(1));
        expect(events[0].files[0].error, 'File too large');
        expect(events[0].files[0].path, '');
      });

      test('handles size as double (numeric coercion)', () async {
        final events = <SharedFilesEvent>[];
        service.stream.listen(events.add);

        await simulateCall(service, 'onFilesShared', {
          'files': [
            {
              'path': '/data/shared/file.dat',
              'name': 'file.dat',
              'size': 42.0,
              'error': null,
            },
          ],
          'text': null,
        });

        await Future.delayed(Duration.zero);
        expect(events, hasLength(1));
        expect(events[0].files[0].size, 42);
      });

      test('handles very large size values', () async {
        final events = <SharedFilesEvent>[];
        service.stream.listen(events.add);

        await simulateCall(service, 'onFilesShared', {
          'files': [
            {
              'path': '/data/shared/big.mp4',
              'name': 'big.mp4',
              'size': 524288000, // 500MB
              'error': null,
            },
          ],
          'text': null,
        });

        await Future.delayed(Duration.zero);
        expect(events[0].files[0].size, 524288000);
      });
    });

    group('buffering (cold start)', () {
      test('buffers event when no listener attached', () async {
        await simulateCall(service, 'onFilesShared', {
          'files': [
            {
              'path': '/data/shared/photo.jpg',
              'name': 'photo.jpg',
              'size': 1024,
              'error': null,
            },
          ],
          'text': null,
        });

        final pending = service.consumePending();
        expect(pending, isNotNull);
        expect(pending!.files, hasLength(1));
        expect(pending.files[0].name, 'photo.jpg');
      });

      test('consumePending returns null after consumption', () async {
        await simulateCall(service, 'onFilesShared', {
          'files': [
            {'path': '/a', 'name': 'a.jpg', 'size': 1024, 'error': null},
          ],
          'text': null,
        });

        final first = service.consumePending();
        expect(first, isNotNull);

        final second = service.consumePending();
        expect(second, isNull);
      });

      test('consumePending returns null when no events ever buffered', () {
        expect(service.consumePending(), isNull);
      });

      test('latest buffered event overwrites previous', () async {
        await simulateCall(service, 'onFilesShared', {
          'files': [
            {'path': '/a.jpg', 'name': 'a.jpg', 'size': 1, 'error': null},
          ],
          'text': null,
        });
        await simulateCall(service, 'onFilesShared', {
          'files': [
            {'path': '/b.jpg', 'name': 'b.jpg', 'size': 2, 'error': null},
          ],
          'text': null,
        });

        final pending = service.consumePending();
        expect(pending, isNotNull);
        expect(pending!.files[0].name, 'b.jpg');
      });

      test('events go to stream when listener present, not buffer', () async {
        final events = <SharedFilesEvent>[];
        service.stream.listen(events.add);

        await simulateCall(service, 'onFilesShared', {
          'files': [
            {'path': '/a.jpg', 'name': 'a.jpg', 'size': 1, 'error': null},
          ],
          'text': null,
        });

        await Future.delayed(Duration.zero);
        expect(events, hasLength(1));
        expect(service.consumePending(), isNull);
      });

      test('buffer is used even when listener subscribes later', () async {
        // Send event with no listener
        await simulateCall(service, 'onFilesShared', {
          'files': [
            {'path': '/a.jpg', 'name': 'a.jpg', 'size': 1, 'error': null},
          ],
          'text': null,
        });

        // Now subscribe — the event should NOT arrive via stream
        final events = <SharedFilesEvent>[];
        service.stream.listen(events.add);
        await Future.delayed(Duration.zero);
        expect(events, isEmpty);

        // But should be available via consumePending
        final pending = service.consumePending();
        expect(pending, isNotNull);
        expect(pending!.files[0].name, 'a.jpg');
      });
    });

    group('stream behavior', () {
      test('multiple events delivered in order', () async {
        final events = <SharedFilesEvent>[];
        service.stream.listen(events.add);

        for (var i = 0; i < 5; i++) {
          await simulateCall(service, 'onFilesShared', {
            'files': [
              {
                'path': '/file_$i',
                'name': 'file_$i',
                'size': i,
                'error': null,
              },
            ],
            'text': null,
          });
        }

        await Future.delayed(Duration.zero);
        expect(events, hasLength(5));
        for (var i = 0; i < 5; i++) {
          expect(events[i].files[0].name, 'file_$i');
        }
      });

      test('broadcasts to multiple listeners', () async {
        final events1 = <SharedFilesEvent>[];
        final events2 = <SharedFilesEvent>[];
        service.stream.listen(events1.add);
        service.stream.listen(events2.add);

        await simulateCall(service, 'onFilesShared', {
          'files': [
            {'path': '/a.jpg', 'name': 'a.jpg', 'size': 1, 'error': null},
          ],
          'text': null,
        });

        await Future.delayed(Duration.zero);
        expect(events1, hasLength(1));
        expect(events2, hasLength(1));
      });

      test('listener can unsubscribe', () async {
        final events = <SharedFilesEvent>[];
        final sub = service.stream.listen(events.add);

        await simulateCall(service, 'onFilesShared', {
          'files': [
            {'path': '/a.jpg', 'name': 'a.jpg', 'size': 1, 'error': null},
          ],
          'text': null,
        });
        await Future.delayed(Duration.zero);
        expect(events, hasLength(1));

        await sub.cancel();

        await simulateCall(service, 'onFilesShared', {
          'files': [
            {'path': '/b.jpg', 'name': 'b.jpg', 'size': 1, 'error': null},
          ],
          'text': null,
        });
        await Future.delayed(Duration.zero);
        // Should still be 1 since we unsubscribed
        // Note: with broadcast stream and no remaining listeners,
        // the event goes to buffer
        expect(events, hasLength(1));
      });
    });

    group('error handling', () {
      test('ignores unknown method calls', () async {
        final events = <SharedFilesEvent>[];
        service.stream.listen(events.add);

        await simulateCall(service, 'unknownMethod', {});

        await Future.delayed(Duration.zero);
        expect(events, isEmpty);
      });

      test('handles null files list gracefully', () async {
        final events = <SharedFilesEvent>[];
        service.stream.listen(events.add);

        await simulateCall(service, 'onFilesShared', {
          'files': null,
          'text': 'some text',
        });

        await Future.delayed(Duration.zero);
        expect(events, hasLength(1));
        expect(events[0].files, isEmpty);
        expect(events[0].text, 'some text');
      });

      test('handles missing fields in file map gracefully', () async {
        final events = <SharedFilesEvent>[];
        service.stream.listen(events.add);

        await simulateCall(service, 'onFilesShared', {
          'files': [<String, dynamic>{}],
          'text': null,
        });

        await Future.delayed(Duration.zero);
        expect(events, hasLength(1));
        expect(events[0].files[0].path, '');
        expect(events[0].files[0].name, 'unknown');
        expect(events[0].files[0].size, 0);
        expect(events[0].files[0].error, isNull);
      });

      test('does not crash on malformed arguments (non-map)', () async {
        final events = <SharedFilesEvent>[];
        service.stream.listen(events.add);

        // Completely wrong type — should not throw, just skip
        await simulateCall(service, 'onFilesShared', 'not a map');

        await Future.delayed(Duration.zero);
        expect(events, isEmpty);
      });

      test('does not crash on null arguments', () async {
        final events = <SharedFilesEvent>[];
        service.stream.listen(events.add);

        await simulateCall(service, 'onFilesShared', null);

        await Future.delayed(Duration.zero);
        expect(events, isEmpty);
      });
    });
  });

  group('SharedFileInfo', () {
    test('stores all fields', () {
      final info = SharedFileInfo(
        path: '/test/path',
        name: 'test.pdf',
        size: 12345,
        error: null,
      );

      expect(info.path, '/test/path');
      expect(info.name, 'test.pdf');
      expect(info.size, 12345);
      expect(info.error, isNull);
    });

    test('stores error string', () {
      final info = SharedFileInfo(
        path: '',
        name: 'big.mp4',
        size: 999999,
        error: 'File too large',
      );

      expect(info.error, 'File too large');
      expect(info.path, '');
    });

    test('zero size is valid', () {
      final info = SharedFileInfo(path: '/a', name: 'a', size: 0);
      expect(info.size, 0);
    });
  });

  group('SharedFilesEvent', () {
    test('stores files and text', () {
      final event = SharedFilesEvent(
        files: [
          SharedFileInfo(path: '/a', name: 'a', size: 1),
          SharedFileInfo(path: '/b', name: 'b', size: 2),
        ],
        text: 'hello',
      );

      expect(event.files, hasLength(2));
      expect(event.text, 'hello');
    });

    test('text defaults to null', () {
      final event = SharedFilesEvent(files: []);
      expect(event.text, isNull);
    });

    test('empty files list is valid', () {
      final event = SharedFilesEvent(files: []);
      expect(event.files, isEmpty);
    });

    test('mixed valid and error files', () {
      final event = SharedFilesEvent(
        files: [
          SharedFileInfo(path: '/ok', name: 'ok.jpg', size: 100),
          SharedFileInfo(
            path: '',
            name: 'bad.mp4',
            size: 0,
            error: 'Too large',
          ),
        ],
      );

      final valid = event.files.where((f) => f.error == null).toList();
      final errors = event.files.where((f) => f.error != null).toList();
      expect(valid, hasLength(1));
      expect(errors, hasLength(1));
    });
  });
}
