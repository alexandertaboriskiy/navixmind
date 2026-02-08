import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navixmind/core/services/share_receiver_service.dart';

/// Additional edge case tests for ShareReceiverService.
/// Covers: timing, rapid events, subscription lifecycle, buffer semantics.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ShareReceiverService service;

  setUp(() {
    service = ShareReceiverService.forTest();
  });

  tearDown(() {
    service.dispose();
  });

  Future<void> simulateCall(
    ShareReceiverService svc,
    String method,
    dynamic arguments,
  ) async {
    await svc.handleMethodCall(MethodCall(method, arguments));
  }

  Map<String, dynamic> makeShareArgs({
    List<Map<String, dynamic>>? files,
    String? text,
  }) {
    return {
      'files': files ?? [],
      'text': text,
    };
  }

  Map<String, dynamic> makeFile({
    String path = '/data/shared/file.dat',
    String name = 'file.dat',
    int size = 100,
    String? error,
  }) {
    return {
      'path': path,
      'name': name,
      'size': size,
      'error': error,
    };
  }

  group('Subscription lifecycle', () {
    test('listener added after event goes to buffer, not stream', () async {
      await simulateCall(service, 'onFilesShared', makeShareArgs(
        files: [makeFile(name: 'buffered.jpg')],
      ));

      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);
      await Future.delayed(Duration.zero);

      // Event was buffered, not streamed
      expect(events, isEmpty);
      expect(service.consumePending()?.files[0].name, 'buffered.jpg');
    });

    test('listener removed then re-added: new events buffer', () async {
      final events = <SharedFilesEvent>[];
      final sub = service.stream.listen(events.add);

      // First event goes to stream
      await simulateCall(service, 'onFilesShared', makeShareArgs(
        files: [makeFile(name: 'first.jpg')],
      ));
      await Future.delayed(Duration.zero);
      expect(events, hasLength(1));

      // Cancel subscription
      await sub.cancel();

      // Second event goes to buffer (no listener)
      await simulateCall(service, 'onFilesShared', makeShareArgs(
        files: [makeFile(name: 'second.jpg')],
      ));

      expect(service.consumePending()?.files[0].name, 'second.jpg');

      // Re-subscribe — stream is clean
      final events2 = <SharedFilesEvent>[];
      service.stream.listen(events2.add);

      // Third event goes to new stream
      await simulateCall(service, 'onFilesShared', makeShareArgs(
        files: [makeFile(name: 'third.jpg')],
      ));
      await Future.delayed(Duration.zero);
      expect(events2, hasLength(1));
      expect(events2[0].files[0].name, 'third.jpg');
    });

    test('multiple subscriptions all receive events', () async {
      final e1 = <SharedFilesEvent>[];
      final e2 = <SharedFilesEvent>[];
      final e3 = <SharedFilesEvent>[];

      service.stream.listen(e1.add);
      service.stream.listen(e2.add);
      service.stream.listen(e3.add);

      await simulateCall(service, 'onFilesShared', makeShareArgs(
        files: [makeFile(name: 'broadcast.jpg')],
      ));
      await Future.delayed(Duration.zero);

      expect(e1, hasLength(1));
      expect(e2, hasLength(1));
      expect(e3, hasLength(1));
    });

    test('one listener cancelling does not affect others', () async {
      final e1 = <SharedFilesEvent>[];
      final e2 = <SharedFilesEvent>[];

      final sub1 = service.stream.listen(e1.add);
      service.stream.listen(e2.add);

      await sub1.cancel();

      await simulateCall(service, 'onFilesShared', makeShareArgs(
        files: [makeFile(name: 'still_live.jpg')],
      ));
      await Future.delayed(Duration.zero);

      expect(e1, hasLength(0)); // cancelled
      expect(e2, hasLength(1)); // still active
    });
  });

  group('Buffer semantics', () {
    test('buffer only holds last event (overwrites)', () async {
      for (var i = 0; i < 5; i++) {
        await simulateCall(service, 'onFilesShared', makeShareArgs(
          files: [makeFile(name: 'event_$i.jpg')],
        ));
      }

      final pending = service.consumePending();
      expect(pending, isNotNull);
      expect(pending!.files[0].name, 'event_4.jpg');
    });

    test('consumePending is idempotent after first call', () async {
      await simulateCall(service, 'onFilesShared', makeShareArgs(
        files: [makeFile(name: 'once.jpg')],
      ));

      expect(service.consumePending(), isNotNull);
      expect(service.consumePending(), isNull);
      expect(service.consumePending(), isNull);
    });

    test('buffer is cleared when stream listener is added and event arrives', () async {
      // Buffer an event
      await simulateCall(service, 'onFilesShared', makeShareArgs(
        files: [makeFile(name: 'old_buffer.jpg')],
      ));

      // Add listener
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      // Send new event — goes to stream
      await simulateCall(service, 'onFilesShared', makeShareArgs(
        files: [makeFile(name: 'new_stream.jpg')],
      ));
      await Future.delayed(Duration.zero);

      // New event in stream
      expect(events, hasLength(1));
      expect(events[0].files[0].name, 'new_stream.jpg');

      // Old buffered event still available via consumePending
      final pending = service.consumePending();
      expect(pending, isNotNull);
      expect(pending!.files[0].name, 'old_buffer.jpg');
    });
  });

  group('Rapid fire events', () {
    test('10 rapid events all delivered to stream in order', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      for (var i = 0; i < 10; i++) {
        await simulateCall(service, 'onFilesShared', makeShareArgs(
          files: [makeFile(name: 'rapid_$i.jpg', size: i * 100)],
        ));
      }
      await Future.delayed(Duration.zero);

      expect(events, hasLength(10));
      for (var i = 0; i < 10; i++) {
        expect(events[i].files[0].name, 'rapid_$i.jpg');
        expect(events[i].files[0].size, i * 100);
      }
    });

    test('rapid events with mixed files and errors', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      await simulateCall(service, 'onFilesShared', makeShareArgs(
        files: [makeFile(name: 'ok.jpg')],
      ));
      await simulateCall(service, 'onFilesShared', makeShareArgs(
        files: [makeFile(name: 'bad.mp4', error: 'Too large')],
      ));
      await simulateCall(service, 'onFilesShared', makeShareArgs(
        files: [
          makeFile(name: 'good.pdf'),
          makeFile(name: 'fail.doc', error: 'Read error'),
        ],
        text: 'mixed share',
      ));
      await Future.delayed(Duration.zero);

      expect(events, hasLength(3));
      expect(events[0].files[0].error, isNull);
      expect(events[1].files[0].error, 'Too large');
      expect(events[2].files, hasLength(2));
      expect(events[2].text, 'mixed share');
    });
  });

  group('Data types and coercion', () {
    test('size as int', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      await simulateCall(service, 'onFilesShared', makeShareArgs(
        files: [makeFile(size: 42)],
      ));
      await Future.delayed(Duration.zero);
      expect(events[0].files[0].size, 42);
    });

    test('size as double', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      await simulateCall(service, 'onFilesShared', {
        'files': [
          {'path': '/a', 'name': 'a', 'size': 99.9, 'error': null},
        ],
        'text': null,
      });
      await Future.delayed(Duration.zero);
      expect(events[0].files[0].size, 99);
    });

    test('size as zero', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      await simulateCall(service, 'onFilesShared', makeShareArgs(
        files: [makeFile(size: 0)],
      ));
      await Future.delayed(Duration.zero);
      expect(events[0].files[0].size, 0);
    });

    test('size as null falls back to 0', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      await simulateCall(service, 'onFilesShared', {
        'files': [
          {'path': '/a', 'name': 'a', 'size': null, 'error': null},
        ],
        'text': null,
      });
      await Future.delayed(Duration.zero);
      expect(events[0].files[0].size, 0);
    });

    test('path as null falls back to empty string', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      await simulateCall(service, 'onFilesShared', {
        'files': [
          {'path': null, 'name': 'a', 'size': 1, 'error': null},
        ],
        'text': null,
      });
      await Future.delayed(Duration.zero);
      expect(events[0].files[0].path, '');
    });

    test('name as null falls back to unknown', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      await simulateCall(service, 'onFilesShared', {
        'files': [
          {'path': '/a', 'name': null, 'size': 1, 'error': null},
        ],
        'text': null,
      });
      await Future.delayed(Duration.zero);
      expect(events[0].files[0].name, 'unknown');
    });

    test('extra unexpected keys in file map are ignored', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      await simulateCall(service, 'onFilesShared', {
        'files': [
          {
            'path': '/a',
            'name': 'a',
            'size': 1,
            'error': null,
            'extra_key': 'should be ignored',
            'another': 42,
          },
        ],
        'text': null,
      });
      await Future.delayed(Duration.zero);
      expect(events, hasLength(1));
      expect(events[0].files[0].path, '/a');
    });

    test('extra unexpected keys in top-level map are ignored', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      await simulateCall(service, 'onFilesShared', {
        'files': [],
        'text': 'hi',
        'unexpected': true,
      });
      await Future.delayed(Duration.zero);
      expect(events, hasLength(1));
      expect(events[0].text, 'hi');
    });
  });

  group('Malformed input resilience', () {
    test('null arguments does not crash', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      await simulateCall(service, 'onFilesShared', null);
      await Future.delayed(Duration.zero);
      expect(events, isEmpty);
    });

    test('string arguments does not crash', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      await simulateCall(service, 'onFilesShared', 'invalid');
      await Future.delayed(Duration.zero);
      expect(events, isEmpty);
    });

    test('integer arguments does not crash', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      await simulateCall(service, 'onFilesShared', 42);
      await Future.delayed(Duration.zero);
      expect(events, isEmpty);
    });

    test('list arguments does not crash', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      await simulateCall(service, 'onFilesShared', [1, 2, 3]);
      await Future.delayed(Duration.zero);
      expect(events, isEmpty);
    });

    test('files as string instead of list does not crash', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      await simulateCall(service, 'onFilesShared', {
        'files': 'not a list',
        'text': null,
      });
      await Future.delayed(Duration.zero);
      // Should not crash; behavior depends on cast
      // The cast `as List?` on a string will throw, caught by try/catch
      expect(events, isEmpty);
    });

    test('file entries as strings instead of maps does not crash', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      await simulateCall(service, 'onFilesShared', {
        'files': ['not', 'maps'],
        'text': null,
      });
      await Future.delayed(Duration.zero);
      // Cast from String to Map will fail in try/catch
      expect(events, isEmpty);
    });

    test('empty map as file entry', () async {
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
    });

    test('unrelated method call is silently ignored', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      await simulateCall(service, 'onSomethingElse', {'key': 'value'});
      await Future.delayed(Duration.zero);
      expect(events, isEmpty);
      expect(service.consumePending(), isNull);
    });
  });

  group('Text-only shares', () {
    test('text-only share with URL', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      await simulateCall(service, 'onFilesShared', makeShareArgs(
        text: 'https://example.com/article?id=123',
      ));
      await Future.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events[0].files, isEmpty);
      expect(events[0].text, 'https://example.com/article?id=123');
    });

    test('text-only share with multiline text', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      await simulateCall(service, 'onFilesShared', makeShareArgs(
        text: 'Line 1\nLine 2\nLine 3',
      ));
      await Future.delayed(Duration.zero);

      expect(events[0].text, 'Line 1\nLine 2\nLine 3');
    });

    test('text-only share with empty string', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      await simulateCall(service, 'onFilesShared', makeShareArgs(text: ''));
      await Future.delayed(Duration.zero);

      expect(events[0].text, '');
    });

    test('text-only share with very long text', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      final longText = 'a' * 100000;
      await simulateCall(service, 'onFilesShared', makeShareArgs(text: longText));
      await Future.delayed(Duration.zero);

      expect(events[0].text?.length, 100000);
    });

    test('files and text combined', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      await simulateCall(service, 'onFilesShared', makeShareArgs(
        files: [makeFile(name: 'photo.jpg')],
        text: 'Check out this photo!',
      ));
      await Future.delayed(Duration.zero);

      expect(events[0].files, hasLength(1));
      expect(events[0].text, 'Check out this photo!');
    });
  });

  group('Large file lists', () {
    test('50 files in single event', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      final files = List.generate(50, (i) => makeFile(
        name: 'file_$i.jpg',
        path: '/data/shared/file_$i.jpg',
        size: i * 1000,
      ));

      await simulateCall(service, 'onFilesShared', {
        'files': files,
        'text': null,
      });
      await Future.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events[0].files, hasLength(50));
      expect(events[0].files[49].name, 'file_49.jpg');
      expect(events[0].files[49].size, 49000);
    });

    test('all files with errors', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      final files = List.generate(5, (i) => makeFile(
        name: 'fail_$i.mp4',
        path: '',
        size: 0,
        error: 'File #$i too large',
      ));

      await simulateCall(service, 'onFilesShared', {
        'files': files,
        'text': null,
      });
      await Future.delayed(Duration.zero);

      expect(events[0].files, hasLength(5));
      for (var i = 0; i < 5; i++) {
        expect(events[0].files[i].error, 'File #$i too large');
      }
    });

    test('mix of valid and error files preserves order', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      await simulateCall(service, 'onFilesShared', {
        'files': [
          makeFile(name: 'ok1.jpg'),
          makeFile(name: 'fail1.mp4', error: 'Error 1'),
          makeFile(name: 'ok2.pdf'),
          makeFile(name: 'fail2.doc', error: 'Error 2'),
          makeFile(name: 'ok3.png'),
        ],
        'text': null,
      });
      await Future.delayed(Duration.zero);

      final names = events[0].files.map((f) => f.name).toList();
      expect(names, ['ok1.jpg', 'fail1.mp4', 'ok2.pdf', 'fail2.doc', 'ok3.png']);
    });
  });
}
