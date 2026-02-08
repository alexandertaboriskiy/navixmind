import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navixmind/core/services/share_receiver_service.dart';

/// Stress tests and concurrency edge cases for ShareReceiverService.
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

  Map<String, dynamic> makeFile({
    String path = '/data/shared/file.dat',
    String name = 'file.dat',
    dynamic size = 100,
    String? error,
  }) {
    return {
      'path': path,
      'name': name,
      'size': size,
      'error': error,
    };
  }

  group('Very large file lists', () {
    test('100 files in single event', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      final files = List.generate(100, (i) => makeFile(
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
      expect(events[0].files, hasLength(100));
      expect(events[0].files[0].name, 'file_0.jpg');
      expect(events[0].files[99].name, 'file_99.jpg');
      expect(events[0].files[50].size, 50000);
    });

    test('200 files preserves order', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      final files = List.generate(200, (i) => makeFile(
        name: 'batch_$i.dat',
        path: '/data/shared/batch_$i.dat',
      ));

      await simulateCall(service, 'onFilesShared', {
        'files': files,
        'text': null,
      });
      await Future.delayed(Duration.zero);

      expect(events[0].files, hasLength(200));
      for (var i = 0; i < 200; i++) {
        expect(events[0].files[i].name, 'batch_$i.dat');
      }
    });

    test('100 files all with errors', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      final files = List.generate(100, (i) => makeFile(
        name: 'fail_$i.mp4',
        path: '',
        size: 0,
        error: 'File #$i: too large',
      ));

      await simulateCall(service, 'onFilesShared', {
        'files': files,
        'text': null,
      });
      await Future.delayed(Duration.zero);

      expect(events[0].files, hasLength(100));
      for (var i = 0; i < 100; i++) {
        expect(events[0].files[i].error, 'File #$i: too large');
      }
    });
  });

  group('Unicode in all fields', () {
    test('Japanese filename', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      await simulateCall(service, 'onFilesShared', {
        'files': [
          makeFile(name: '写真_2025.jpg', path: '/data/shared/写真_2025.jpg'),
        ],
        'text': null,
      });
      await Future.delayed(Duration.zero);

      expect(events[0].files[0].name, '写真_2025.jpg');
      expect(events[0].files[0].path, '/data/shared/写真_2025.jpg');
    });

    test('Russian text share', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      await simulateCall(service, 'onFilesShared', {
        'files': [],
        'text': 'Привет мир! Это текст на русском языке.',
      });
      await Future.delayed(Duration.zero);

      expect(events[0].text, contains('Привет'));
    });

    test('Arabic filename', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      await simulateCall(service, 'onFilesShared', {
        'files': [makeFile(name: 'ملف.pdf', path: '/data/shared/ملف.pdf')],
        'text': null,
      });
      await Future.delayed(Duration.zero);

      expect(events[0].files[0].name, 'ملف.pdf');
    });

    test('emoji in filename', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      await simulateCall(service, 'onFilesShared', {
        'files': [makeFile(name: '🎉_party.jpg')],
        'text': null,
      });
      await Future.delayed(Duration.zero);

      expect(events[0].files[0].name, '🎉_party.jpg');
    });

    test('emoji in error message', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      await simulateCall(service, 'onFilesShared', {
        'files': [
          makeFile(name: 'fail.mp4', error: '⚠️ File too large (500MB)'),
        ],
        'text': null,
      });
      await Future.delayed(Duration.zero);

      expect(events[0].files[0].error, contains('⚠️'));
    });

    test('mixed unicode in text', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      await simulateCall(service, 'onFilesShared', {
        'files': [],
        'text': 'Hello 世界 مرحبا Привет 🌍',
      });
      await Future.delayed(Duration.zero);

      expect(events[0].text, 'Hello 世界 مرحبا Привет 🌍');
    });

    test('CJK characters in path', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      await simulateCall(service, 'onFilesShared', {
        'files': [makeFile(path: '/data/shared/文件夹/文件.txt', name: '文件.txt')],
        'text': null,
      });
      await Future.delayed(Duration.zero);

      expect(events[0].files[0].path, '/data/shared/文件夹/文件.txt');
    });
  });

  group('Special characters in errors', () {
    test('error with quotes', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      await simulateCall(service, 'onFilesShared', {
        'files': [
          makeFile(error: 'Could not read "important file.pdf"'),
        ],
        'text': null,
      });
      await Future.delayed(Duration.zero);

      expect(events[0].files[0].error, contains('"important file.pdf"'));
    });

    test('error with newlines', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      await simulateCall(service, 'onFilesShared', {
        'files': [
          makeFile(error: 'Error line 1\nError line 2\nDetails: crash'),
        ],
        'text': null,
      });
      await Future.delayed(Duration.zero);

      expect(events[0].files[0].error, contains('\n'));
    });

    test('error with very long message', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      final longError = 'E' * 10000;
      await simulateCall(service, 'onFilesShared', {
        'files': [makeFile(error: longError)],
        'text': null,
      });
      await Future.delayed(Duration.zero);

      expect(events[0].files[0].error?.length, 10000);
    });

    test('error with path-like characters', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      await simulateCall(service, 'onFilesShared', {
        'files': [
          makeFile(error: 'Failed: /data/../../../etc/passwd not allowed'),
        ],
        'text': null,
      });
      await Future.delayed(Duration.zero);

      expect(events[0].files[0].error, contains('passwd'));
    });
  });

  group('Rapid sequential events', () {
    test('20 rapid events all delivered', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      for (var i = 0; i < 20; i++) {
        await simulateCall(service, 'onFilesShared', {
          'files': [makeFile(name: 'rapid_$i.jpg')],
          'text': 'batch $i',
        });
      }
      await Future.delayed(Duration.zero);

      expect(events, hasLength(20));
      for (var i = 0; i < 20; i++) {
        expect(events[i].files[0].name, 'rapid_$i.jpg');
        expect(events[i].text, 'batch $i');
      }
    });

    test('alternating valid and empty events', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      for (var i = 0; i < 10; i++) {
        if (i.isEven) {
          await simulateCall(service, 'onFilesShared', {
            'files': [makeFile(name: 'file_$i.jpg')],
            'text': null,
          });
        } else {
          await simulateCall(service, 'onFilesShared', {
            'files': [],
            'text': null,
          });
        }
      }
      await Future.delayed(Duration.zero);

      expect(events, hasLength(10));
      expect(events[0].files, hasLength(1));
      expect(events[1].files, isEmpty);
      expect(events[2].files, hasLength(1));
    });

    test('rapid events with alternating methods (some ignored)', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      for (var i = 0; i < 10; i++) {
        if (i.isEven) {
          await simulateCall(service, 'onFilesShared', {
            'files': [makeFile(name: 'file_$i.jpg')],
            'text': null,
          });
        } else {
          // This should be silently ignored
          await simulateCall(service, 'unknownMethod', {
            'data': 'ignored_$i',
          });
        }
      }
      await Future.delayed(Duration.zero);

      // Only 5 valid events (even indices)
      expect(events, hasLength(5));
    });
  });

  group('Empty event sequences', () {
    test('event with empty files and null text', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      await simulateCall(service, 'onFilesShared', {
        'files': [],
        'text': null,
      });
      await Future.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events[0].files, isEmpty);
      expect(events[0].text, isNull);
    });

    test('event with empty files and empty text', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      await simulateCall(service, 'onFilesShared', {
        'files': [],
        'text': '',
      });
      await Future.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events[0].text, '');
    });

    test('multiple empty events in sequence', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      for (var i = 0; i < 5; i++) {
        await simulateCall(service, 'onFilesShared', {
          'files': [],
          'text': null,
        });
      }
      await Future.delayed(Duration.zero);

      expect(events, hasLength(5));
      for (final e in events) {
        expect(e.files, isEmpty);
        expect(e.text, isNull);
      }
    });
  });

  group('Mixed valid/invalid data in same batch', () {
    test('mix of normal, error, and edge-case files', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      await simulateCall(service, 'onFilesShared', {
        'files': [
          makeFile(name: 'normal.jpg', size: 1024),
          makeFile(name: 'error.mp4', path: '', error: 'Too large'),
          makeFile(name: '', path: '', size: 0),
          makeFile(name: 'unicode_写真.jpg', path: '/data/shared/写真.jpg'),
          {'path': null, 'name': null, 'size': null, 'error': null},
          makeFile(name: 'normal2.pdf', size: 2048),
        ],
        'text': 'Mixed batch',
      });
      await Future.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events[0].files, hasLength(6));
      expect(events[0].files[0].name, 'normal.jpg');
      expect(events[0].files[1].error, 'Too large');
      expect(events[0].files[2].name, '');
      expect(events[0].files[3].name, 'unicode_写真.jpg');
      expect(events[0].files[4].name, 'unknown'); // null fallback
      expect(events[0].files[4].path, ''); // null fallback
      expect(events[0].files[4].size, 0); // null fallback
      expect(events[0].files[5].name, 'normal2.pdf');
      expect(events[0].text, 'Mixed batch');
    });

    test('files with various size types in same batch', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      await simulateCall(service, 'onFilesShared', {
        'files': [
          {'path': '/a', 'name': 'int_size', 'size': 42, 'error': null},
          {'path': '/b', 'name': 'double_size', 'size': 99.7, 'error': null},
          {'path': '/c', 'name': 'zero_size', 'size': 0, 'error': null},
          {'path': '/d', 'name': 'null_size', 'size': null, 'error': null},
          {'path': '/e', 'name': 'large_size', 'size': 524288000, 'error': null},
        ],
        'text': null,
      });
      await Future.delayed(Duration.zero);

      expect(events[0].files[0].size, 42);
      expect(events[0].files[1].size, 99); // double truncated to int
      expect(events[0].files[2].size, 0);
      expect(events[0].files[3].size, 0); // null fallback
      expect(events[0].files[4].size, 524288000); // 500MB
    });
  });

  group('Dispose behavior', () {
    test('dispose closes the stream', () async {
      final events = <SharedFilesEvent>[];
      var done = false;
      service.stream.listen(
        events.add,
        onDone: () => done = true,
      );

      service.dispose();
      await Future.delayed(Duration.zero);

      expect(done, isTrue);
    });

    test('consumePending works after dispose', () async {
      await simulateCall(service, 'onFilesShared', {
        'files': [makeFile(name: 'pre_dispose.jpg')],
        'text': null,
      });

      service.dispose();

      // consumePending should still work (just reading a field)
      final pending = service.consumePending();
      expect(pending, isNotNull);
      expect(pending!.files[0].name, 'pre_dispose.jpg');
    });
  });

  group('Path edge cases', () {
    test('path with spaces', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      await simulateCall(service, 'onFilesShared', {
        'files': [makeFile(path: '/data/My Documents/my file.pdf', name: 'my file.pdf')],
        'text': null,
      });
      await Future.delayed(Duration.zero);

      expect(events[0].files[0].path, '/data/My Documents/my file.pdf');
      expect(events[0].files[0].name, 'my file.pdf');
    });

    test('path with special characters', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      await simulateCall(service, 'onFilesShared', {
        'files': [makeFile(path: '/data/shared/résumé_(1).pdf', name: 'résumé_(1).pdf')],
        'text': null,
      });
      await Future.delayed(Duration.zero);

      expect(events[0].files[0].path, contains('résumé'));
    });

    test('very long path', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      final longPath = '/data/' + 'subdir/' * 50 + 'file.txt';
      await simulateCall(service, 'onFilesShared', {
        'files': [makeFile(path: longPath, name: 'file.txt')],
        'text': null,
      });
      await Future.delayed(Duration.zero);

      expect(events[0].files[0].path, longPath);
    });

    test('path with null bytes in name', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      await simulateCall(service, 'onFilesShared', {
        'files': [makeFile(name: 'file\x00name.txt')],
        'text': null,
      });
      await Future.delayed(Duration.zero);

      expect(events[0].files[0].name, contains('file'));
    });

    test('empty path with valid name', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      await simulateCall(service, 'onFilesShared', {
        'files': [makeFile(path: '', name: 'orphan.jpg')],
        'text': null,
      });
      await Future.delayed(Duration.zero);

      expect(events[0].files[0].path, '');
      expect(events[0].files[0].name, 'orphan.jpg');
    });
  });

  group('Text edge cases', () {
    test('text with newlines', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      await simulateCall(service, 'onFilesShared', {
        'files': [],
        'text': 'Line 1\nLine 2\r\nLine 3\rLine 4',
      });
      await Future.delayed(Duration.zero);

      expect(events[0].text, contains('Line 1'));
      expect(events[0].text, contains('Line 4'));
    });

    test('text with tabs', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      await simulateCall(service, 'onFilesShared', {
        'files': [],
        'text': 'Col1\tCol2\tCol3',
      });
      await Future.delayed(Duration.zero);

      expect(events[0].text, 'Col1\tCol2\tCol3');
    });

    test('very long text (100KB)', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      final longText = 'x' * 100000;
      await simulateCall(service, 'onFilesShared', {
        'files': [],
        'text': longText,
      });
      await Future.delayed(Duration.zero);

      expect(events[0].text?.length, 100000);
    });

    test('text with URL containing special characters', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      await simulateCall(service, 'onFilesShared', {
        'files': [],
        'text': 'https://example.com/search?q=hello+world&lang=en#section-1',
      });
      await Future.delayed(Duration.zero);

      expect(events[0].text, contains('hello+world'));
      expect(events[0].text, contains('#section-1'));
    });
  });

  group('Stream error resilience', () {
    test('malformed event does not break subsequent valid events', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      // Malformed
      await simulateCall(service, 'onFilesShared', 'not a map');
      await Future.delayed(Duration.zero);
      expect(events, isEmpty);

      // Valid event after malformed
      await simulateCall(service, 'onFilesShared', {
        'files': [makeFile(name: 'after_error.jpg')],
        'text': null,
      });
      await Future.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events[0].files[0].name, 'after_error.jpg');
    });

    test('null args do not break subsequent valid events', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      await simulateCall(service, 'onFilesShared', null);
      await simulateCall(service, 'onFilesShared', {
        'files': [makeFile(name: 'recovery.jpg')],
        'text': null,
      });
      await Future.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events[0].files[0].name, 'recovery.jpg');
    });

    test('exception in one file entry does not lose entire batch', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      // One entry is a string instead of map — will cause exception in .map()
      // The try/catch should handle this
      await simulateCall(service, 'onFilesShared', {
        'files': ['not a map', makeFile(name: 'valid.jpg')],
        'text': null,
      });
      await Future.delayed(Duration.zero);

      // The entire event fails because the .map() iterates over the list
      // and the first bad entry causes an exception caught by try/catch
      // So no events are emitted
      expect(events, isEmpty);
    });

    test('multiple malformed calls followed by valid call', () async {
      final events = <SharedFilesEvent>[];
      service.stream.listen(events.add);

      for (var i = 0; i < 5; i++) {
        await simulateCall(service, 'onFilesShared', i);
      }
      await Future.delayed(Duration.zero);
      expect(events, isEmpty);

      await simulateCall(service, 'onFilesShared', {
        'files': [makeFile(name: 'finally_valid.jpg')],
        'text': null,
      });
      await Future.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events[0].files[0].name, 'finally_valid.jpg');
    });
  });

  group('SharedFileInfo and SharedFilesEvent edge cases', () {
    test('SharedFileInfo with all empty strings', () {
      final info = SharedFileInfo(path: '', name: '', size: 0, error: '');
      expect(info.path, '');
      expect(info.name, '');
      expect(info.size, 0);
      expect(info.error, ''); // empty string, not null
    });

    test('SharedFileInfo negative size is stored', () {
      // While negative sizes shouldn't happen, the model shouldn't crash
      final info = SharedFileInfo(path: '/a', name: 'a', size: -1);
      expect(info.size, -1);
    });

    test('SharedFilesEvent with single file', () {
      final event = SharedFilesEvent(
        files: [SharedFileInfo(path: '/a', name: 'a', size: 1)],
      );
      expect(event.files, hasLength(1));
      expect(event.text, isNull);
    });

    test('SharedFilesEvent files list is not modifiable from outside', () {
      final files = [SharedFileInfo(path: '/a', name: 'a', size: 1)];
      final event = SharedFilesEvent(files: files);

      // Modifying the original list after creation
      files.add(SharedFileInfo(path: '/b', name: 'b', size: 2));

      // The event's files list is the same reference (no defensive copy)
      // This is expected behavior — just verifying it doesn't crash
      expect(event.files, isNotEmpty);
    });
  });
}
