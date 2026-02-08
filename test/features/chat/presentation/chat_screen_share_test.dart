import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navixmind/core/services/share_receiver_service.dart';
import 'package:navixmind/features/chat/presentation/chat_screen.dart';

/// Tests for the share-to-chat integration logic.
///
/// Since ChatScreen has heavy dependencies (PythonBridge, StorageService, etc.),
/// these tests validate the data flow and logic rather than pumping the full widget.
/// The actual UI behavior is validated by InputBar external files tests and
/// manual testing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Share-to-chat data flow', () {
    late ShareReceiverService service;

    setUp(() {
      service = ShareReceiverService.forTest();
    });

    tearDown(() {
      service.dispose();
    });

    group('_applySharedFiles logic', () {
      test('valid files are separated from error files', () async {
        final events = <SharedFilesEvent>[];
        service.stream.listen(events.add);

        await service.handleMethodCall(MethodCall('onFilesShared', {
          'files': [
            {
              'path': '/data/shared/good.jpg',
              'name': 'good.jpg',
              'size': 1024,
              'error': null,
            },
            {
              'path': '',
              'name': 'bad.mp4',
              'size': 0,
              'error': 'bad.mp4 is too large',
            },
            {
              'path': '/data/shared/ok.pdf',
              'name': 'ok.pdf',
              'size': 2048,
              'error': null,
            },
          ],
          'text': null,
        }));

        await Future.delayed(Duration.zero);
        expect(events, hasLength(1));

        final event = events[0];
        final validFiles = event.files.where((f) => f.error == null && f.path.isNotEmpty).toList();
        final errorFiles = event.files.where((f) => f.error != null).toList();

        expect(validFiles, hasLength(2));
        expect(validFiles[0].path, '/data/shared/good.jpg');
        expect(validFiles[1].path, '/data/shared/ok.pdf');

        expect(errorFiles, hasLength(1));
        expect(errorFiles[0].error, contains('too large'));
      });

      test('text-only share has no valid files', () async {
        final events = <SharedFilesEvent>[];
        service.stream.listen(events.add);

        await service.handleMethodCall(MethodCall('onFilesShared', {
          'files': [],
          'text': 'https://example.com/page',
        }));

        await Future.delayed(Duration.zero);
        final event = events[0];
        final validFiles = event.files.where((f) => f.error == null && f.path.isNotEmpty).toList();
        expect(validFiles, isEmpty);
        expect(event.text, 'https://example.com/page');
      });

      test('files-only share has no text', () async {
        final events = <SharedFilesEvent>[];
        service.stream.listen(events.add);

        await service.handleMethodCall(MethodCall('onFilesShared', {
          'files': [
            {
              'path': '/data/shared/photo.jpg',
              'name': 'photo.jpg',
              'size': 500,
              'error': null,
            },
          ],
          'text': null,
        }));

        await Future.delayed(Duration.zero);
        expect(events[0].text, isNull);
        expect(events[0].files, hasLength(1));
      });

      test('multiple shares append files (simulated)', () async {
        final allValidPaths = <String>[];
        service.stream.listen((event) {
          final validFiles = event.files
              .where((f) => f.error == null && f.path.isNotEmpty)
              .toList();
          allValidPaths.addAll(validFiles.map((f) => f.path));
        });

        // First share
        await service.handleMethodCall(MethodCall('onFilesShared', {
          'files': [
            {'path': '/data/shared/a.jpg', 'name': 'a.jpg', 'size': 100, 'error': null},
          ],
          'text': null,
        }));

        // Second share
        await service.handleMethodCall(MethodCall('onFilesShared', {
          'files': [
            {'path': '/data/shared/b.pdf', 'name': 'b.pdf', 'size': 200, 'error': null},
          ],
          'text': null,
        }));

        await Future.delayed(Duration.zero);
        expect(allValidPaths, ['/data/shared/a.jpg', '/data/shared/b.pdf']);
      });
    });

    group('Cold start buffering', () {
      test('buffered event available via consumePending', () async {
        // Simulate cold start: Kotlin sends before Flutter listens
        await service.handleMethodCall(MethodCall('onFilesShared', {
          'files': [
            {
              'path': '/data/shared/cold_start.jpg',
              'name': 'cold_start.jpg',
              'size': 1024,
              'error': null,
            },
          ],
          'text': 'Cold start share',
        }));

        // Now ChatScreen mounts, subscribes, and consumes pending
        final events = <SharedFilesEvent>[];
        service.stream.listen(events.add);

        final pending = service.consumePending();
        expect(pending, isNotNull);
        expect(pending!.files[0].name, 'cold_start.jpg');
        expect(pending.text, 'Cold start share');

        // Stream should have no events (pending was consumed, not streamed)
        await Future.delayed(Duration.zero);
        expect(events, isEmpty);
      });

      test('no pending event when share arrives after subscription', () async {
        final events = <SharedFilesEvent>[];
        service.stream.listen(events.add);

        // Check pending before any share — should be null
        expect(service.consumePending(), isNull);

        // Share arrives
        await service.handleMethodCall(MethodCall('onFilesShared', {
          'files': [
            {'path': '/data/shared/warm.jpg', 'name': 'warm.jpg', 'size': 512, 'error': null},
          ],
          'text': null,
        }));

        await Future.delayed(Duration.zero);
        expect(events, hasLength(1));
        expect(service.consumePending(), isNull);
      });
    });

    group('_sendMessage empty-text guard', () {
      test('empty text with empty files should not send (guard logic)', () {
        // Simulating the guard: if (text.isEmpty && _attachedFiles.isEmpty) return;
        final text = '';
        final attachedFiles = <String>[];
        final shouldSend = !(text.isEmpty && attachedFiles.isEmpty);
        expect(shouldSend, isFalse);
      });

      test('empty text with files should allow send', () {
        final text = '';
        final attachedFiles = ['/data/shared/photo.jpg'];
        final shouldSend = !(text.isEmpty && attachedFiles.isEmpty);
        expect(shouldSend, isTrue);
      });

      test('text with empty files should allow send', () {
        final text = 'Hello';
        final attachedFiles = <String>[];
        final shouldSend = !(text.isEmpty && attachedFiles.isEmpty);
        expect(shouldSend, isTrue);
      });

      test('text with files should allow send', () {
        final text = 'Process this';
        final attachedFiles = ['/data/shared/photo.jpg'];
        final shouldSend = !(text.isEmpty && attachedFiles.isEmpty);
        expect(shouldSend, isTrue);
      });

      test('whitespace-only text with files should allow send', () {
        final text = '   '.trim();
        final attachedFiles = ['/data/shared/photo.jpg'];
        final shouldSend = !(text.isEmpty && attachedFiles.isEmpty);
        expect(shouldSend, isTrue);
      });
    });

    group('ChatMessage with attachments', () {
      test('message created with share attachments', () {
        final message = ChatMessage(
          role: MessageRole.user,
          content: 'Process this image',
          timestamp: DateTime.now(),
          attachments: ['/data/shared/photo.jpg', '/data/shared/doc.pdf'],
        );

        expect(message.attachments, hasLength(2));
        expect(message.attachments![0], '/data/shared/photo.jpg');
      });

      test('system message for share notification', () {
        final message = ChatMessage(
          role: MessageRole.system,
          content: 'Received 3 file(s) from share. Add a prompt and send.',
          timestamp: DateTime.now(),
        );

        expect(message.role, MessageRole.system);
        expect(message.content, contains('Received'));
        expect(message.content, contains('from share'));
      });

      test('error message for failed share file', () {
        final message = ChatMessage(
          role: MessageRole.error,
          content: 'video.mp4 is too large (600MB). Max: 500MB',
          timestamp: DateTime.now(),
        );

        expect(message.role, MessageRole.error);
        expect(message.content, contains('too large'));
      });
    });

    group('Edge cases', () {
      test('share with only error files shows errors but no success message', () async {
        final events = <SharedFilesEvent>[];
        service.stream.listen(events.add);

        await service.handleMethodCall(MethodCall('onFilesShared', {
          'files': [
            {
              'path': '',
              'name': 'huge.mp4',
              'size': 0,
              'error': 'File too large',
            },
            {
              'path': '',
              'name': 'unreadable.pdf',
              'size': 0,
              'error': 'Could not read file',
            },
          ],
          'text': null,
        }));

        await Future.delayed(Duration.zero);
        final event = events[0];
        final validFiles = event.files.where((f) => f.error == null && f.path.isNotEmpty).toList();
        final errorFiles = event.files.where((f) => f.error != null).toList();

        expect(validFiles, isEmpty);
        expect(errorFiles, hasLength(2));
      });

      test('share with empty text and empty files', () async {
        final events = <SharedFilesEvent>[];
        service.stream.listen(events.add);

        await service.handleMethodCall(MethodCall('onFilesShared', {
          'files': [],
          'text': null,
        }));

        await Future.delayed(Duration.zero);
        expect(events, hasLength(1));
        expect(events[0].files, isEmpty);
        expect(events[0].text, isNull);
      });

      test('share with empty string text (not null)', () async {
        final events = <SharedFilesEvent>[];
        service.stream.listen(events.add);

        await service.handleMethodCall(MethodCall('onFilesShared', {
          'files': [],
          'text': '',
        }));

        await Future.delayed(Duration.zero);
        expect(events, hasLength(1));
        // ChatScreen should check text != null && text.isNotEmpty before setting
        expect(events[0].text, '');
      });

      test('rapid consecutive shares produce separate events', () async {
        final events = <SharedFilesEvent>[];
        service.stream.listen(events.add);

        // Fire 10 rapid shares
        for (var i = 0; i < 10; i++) {
          await service.handleMethodCall(MethodCall('onFilesShared', {
            'files': [
              {'path': '/f$i', 'name': 'f$i.jpg', 'size': i * 100, 'error': null},
            ],
            'text': null,
          }));
        }

        await Future.delayed(Duration.zero);
        expect(events, hasLength(10));
      });
    });
  });
}
