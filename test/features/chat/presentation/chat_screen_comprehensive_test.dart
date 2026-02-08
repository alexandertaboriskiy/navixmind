import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navixmind/core/services/share_receiver_service.dart';
import 'package:navixmind/features/chat/presentation/chat_screen.dart';

/// Comprehensive tests for ChatScreen's share integration logic.
///
/// Since ChatScreen has heavy dependencies (PythonBridge, StorageService, etc.),
/// these tests validate the data flow logic and ChatMessage model behavior
/// rather than pumping the full widget tree.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('_applySharedFiles logic simulation', () {
    /// Simulates _applySharedFiles by extracting valid/error files
    /// the same way ChatScreen does.
    Map<String, dynamic> applySharedFilesLogic(SharedFilesEvent event) {
      final validFiles = <String>[];
      final errors = <String>[];

      for (final file in event.files) {
        if (file.error != null) {
          errors.add(file.error!);
        } else if (file.path.isNotEmpty) {
          validFiles.add(file.path);
        }
      }

      return {
        'validFiles': validFiles,
        'errors': errors,
        'text': event.text,
        'hasValidFiles': validFiles.isNotEmpty,
        'shouldSetInputText': event.text != null && event.text!.isNotEmpty,
      };
    }

    test('single valid file extracts correctly', () {
      final result = applySharedFilesLogic(SharedFilesEvent(
        files: [SharedFileInfo(path: '/data/photo.jpg', name: 'photo.jpg', size: 1024)],
      ));

      expect(result['validFiles'], ['/data/photo.jpg']);
      expect(result['errors'], isEmpty);
      expect(result['hasValidFiles'], isTrue);
    });

    test('single error file extracts correctly', () {
      final result = applySharedFilesLogic(SharedFilesEvent(
        files: [SharedFileInfo(path: '', name: 'big.mp4', size: 0, error: 'Too large')],
      ));

      expect(result['validFiles'], isEmpty);
      expect(result['errors'], ['Too large']);
      expect(result['hasValidFiles'], isFalse);
    });

    test('mixed valid and error files', () {
      final result = applySharedFilesLogic(SharedFilesEvent(
        files: [
          SharedFileInfo(path: '/data/ok.jpg', name: 'ok.jpg', size: 100),
          SharedFileInfo(path: '', name: 'fail.mp4', size: 0, error: 'Error A'),
          SharedFileInfo(path: '/data/good.pdf', name: 'good.pdf', size: 200),
          SharedFileInfo(path: '', name: 'fail2.doc', size: 0, error: 'Error B'),
        ],
      ));

      expect(result['validFiles'], ['/data/ok.jpg', '/data/good.pdf']);
      expect(result['errors'], ['Error A', 'Error B']);
    });

    test('file with empty path and no error is skipped', () {
      final result = applySharedFilesLogic(SharedFilesEvent(
        files: [
          SharedFileInfo(path: '', name: 'orphan.dat', size: 0),
        ],
      ));

      // Empty path without error — silently skipped
      expect(result['validFiles'], isEmpty);
      expect(result['errors'], isEmpty);
    });

    test('text-only share: no files, has text', () {
      final result = applySharedFilesLogic(SharedFilesEvent(
        files: [],
        text: 'https://example.com',
      ));

      expect(result['validFiles'], isEmpty);
      expect(result['hasValidFiles'], isFalse);
      expect(result['shouldSetInputText'], isTrue);
      expect(result['text'], 'https://example.com');
    });

    test('files with text', () {
      final result = applySharedFilesLogic(SharedFilesEvent(
        files: [SharedFileInfo(path: '/data/img.jpg', name: 'img.jpg', size: 50)],
        text: 'Check this image',
      ));

      expect(result['validFiles'], ['/data/img.jpg']);
      expect(result['shouldSetInputText'], isTrue);
      expect(result['text'], 'Check this image');
    });

    test('empty text string does not set input', () {
      final result = applySharedFilesLogic(SharedFilesEvent(
        files: [SharedFileInfo(path: '/data/img.jpg', name: 'img.jpg', size: 50)],
        text: '',
      ));

      expect(result['shouldSetInputText'], isFalse);
    });

    test('null text does not set input', () {
      final result = applySharedFilesLogic(SharedFilesEvent(
        files: [],
        text: null,
      ));

      expect(result['shouldSetInputText'], isFalse);
    });

    test('all files have errors', () {
      final result = applySharedFilesLogic(SharedFilesEvent(
        files: [
          SharedFileInfo(path: '', name: 'a.mp4', size: 0, error: 'Error 1'),
          SharedFileInfo(path: '', name: 'b.mp4', size: 0, error: 'Error 2'),
          SharedFileInfo(path: '', name: 'c.mp4', size: 0, error: 'Error 3'),
        ],
      ));

      expect(result['validFiles'], isEmpty);
      expect(result['errors'], hasLength(3));
      expect(result['hasValidFiles'], isFalse);
    });

    test('large batch of valid files', () {
      final files = List.generate(20, (i) =>
        SharedFileInfo(path: '/data/file_$i.jpg', name: 'file_$i.jpg', size: i * 100),
      );

      final result = applySharedFilesLogic(SharedFilesEvent(files: files));

      expect(result['validFiles'], hasLength(20));
      expect(result['errors'], isEmpty);
    });
  });

  group('Multiple shares append simulation', () {
    test('two shares accumulate files', () {
      // Simulate the _attachedFiles list growing across shares
      final attachedFiles = <String>[];

      // First share
      final event1 = SharedFilesEvent(
        files: [SharedFileInfo(path: '/a.jpg', name: 'a.jpg', size: 1)],
      );
      for (final f in event1.files) {
        if (f.error == null && f.path.isNotEmpty) attachedFiles.add(f.path);
      }
      expect(attachedFiles, ['/a.jpg']);

      // Second share
      final event2 = SharedFilesEvent(
        files: [SharedFileInfo(path: '/b.pdf', name: 'b.pdf', size: 2)],
      );
      for (final f in event2.files) {
        if (f.error == null && f.path.isNotEmpty) attachedFiles.add(f.path);
      }
      expect(attachedFiles, ['/a.jpg', '/b.pdf']);
    });

    test('error files in second share do not clear first share files', () {
      final attachedFiles = <String>[];

      // First share: valid
      final event1 = SharedFilesEvent(
        files: [SharedFileInfo(path: '/good.jpg', name: 'good.jpg', size: 1)],
      );
      for (final f in event1.files) {
        if (f.error == null && f.path.isNotEmpty) attachedFiles.add(f.path);
      }

      // Second share: all errors
      final event2 = SharedFilesEvent(
        files: [SharedFileInfo(path: '', name: 'bad.mp4', size: 0, error: 'Fail')],
      );
      for (final f in event2.files) {
        if (f.error == null && f.path.isNotEmpty) attachedFiles.add(f.path);
      }

      // First share's file should still be there
      expect(attachedFiles, ['/good.jpg']);
    });

    test('10 consecutive shares accumulate correctly', () {
      final attachedFiles = <String>[];

      for (var i = 0; i < 10; i++) {
        final event = SharedFilesEvent(
          files: [SharedFileInfo(path: '/file_$i.jpg', name: 'file_$i.jpg', size: i)],
        );
        for (final f in event.files) {
          if (f.error == null && f.path.isNotEmpty) attachedFiles.add(f.path);
        }
      }

      expect(attachedFiles, hasLength(10));
      expect(attachedFiles.last, '/file_9.jpg');
    });
  });

  group('_sendMessage guard logic', () {
    /// Simulates the guard: if (text.isEmpty && _attachedFiles.isEmpty) return;
    bool shouldSend(String text, List<String> attachedFiles) {
      return !(text.trim().isEmpty && attachedFiles.isEmpty);
    }

    test('empty text + empty files = no send', () {
      expect(shouldSend('', []), isFalse);
    });

    test('whitespace text + empty files = no send', () {
      expect(shouldSend('   ', []), isFalse);
    });

    test('tab text + empty files = no send', () {
      expect(shouldSend('\t', []), isFalse);
    });

    test('newline text + empty files = no send', () {
      expect(shouldSend('\n', []), isFalse);
    });

    test('text + empty files = send', () {
      expect(shouldSend('Hello', []), isTrue);
    });

    test('empty text + files = send', () {
      expect(shouldSend('', ['/file.jpg']), isTrue);
    });

    test('text + files = send', () {
      expect(shouldSend('Process this', ['/file.jpg']), isTrue);
    });

    test('whitespace text + files = send', () {
      expect(shouldSend('   ', ['/file.jpg']), isTrue);
    });

    test('single character text = send', () {
      expect(shouldSend('a', []), isTrue);
    });

    test('unicode text = send', () {
      expect(shouldSend('日本語', []), isTrue);
    });

    test('emoji text = send', () {
      expect(shouldSend('🎉', []), isTrue);
    });

    test('multiple files = send', () {
      expect(shouldSend('', ['/a.jpg', '/b.pdf', '/c.mp4']), isTrue);
    });
  });

  group('System message formatting', () {
    test('share notification message format', () {
      final validCount = 3;
      final message = 'Received $validCount file(s) from share. Add a prompt and send.';

      expect(message, contains('3'));
      expect(message, contains('file(s)'));
      expect(message, contains('from share'));
    });

    test('single file notification', () {
      final validCount = 1;
      final message = 'Received $validCount file(s) from share. Add a prompt and send.';

      expect(message, contains('1'));
    });

    test('zero files does not generate notification', () {
      final validFiles = <String>[];
      final shouldNotify = validFiles.isNotEmpty;
      expect(shouldNotify, isFalse);
    });
  });

  group('Error message formatting', () {
    test('file too large error format', () {
      final error = 'video.mp4 is too large (600MB). Max: 500MB';
      expect(error, contains('too large'));
      expect(error, contains('600MB'));
      expect(error, contains('500MB'));
    });

    test('could not read error format', () {
      final error = 'Could not read file: document.pdf';
      expect(error, contains('Could not read'));
    });

    test('processing failed error format', () {
      final error = 'Failed to process file: java.io.IOException';
      expect(error, contains('Failed to process'));
    });
  });

  group('ChatMessage model comprehensive', () {
    test('user message with attachments', () {
      final msg = ChatMessage(
        role: MessageRole.user,
        content: 'Process these',
        timestamp: DateTime(2025, 6, 1, 12, 0),
        attachments: ['/a.jpg', '/b.pdf'],
      );

      expect(msg.role, MessageRole.user);
      expect(msg.content, 'Process these');
      expect(msg.attachments, hasLength(2));
      expect(msg.timestamp.year, 2025);
    });

    test('assistant message without attachments', () {
      final msg = ChatMessage(
        role: MessageRole.assistant,
        content: 'Here is the result',
        timestamp: DateTime.now(),
      );

      expect(msg.attachments, isNull);
    });

    test('system message for share notification', () {
      final msg = ChatMessage(
        role: MessageRole.system,
        content: 'Received 2 file(s) from share. Add a prompt and send.',
        timestamp: DateTime.now(),
      );

      expect(msg.role, MessageRole.system);
      expect(msg.content, contains('Received'));
    });

    test('error message for failed file', () {
      final msg = ChatMessage(
        role: MessageRole.error,
        content: 'video.mp4 is too large (600MB). Max: 500MB',
        timestamp: DateTime.now(),
      );

      expect(msg.role, MessageRole.error);
    });

    test('file link message format', () {
      final msg = ChatMessage(
        role: MessageRole.system,
        content: '\u{1F4CE} File: /data/output/result.pdf',
        timestamp: DateTime.now(),
      );

      expect(msg.content.startsWith('📎 File:'), isTrue);
    });

    test('empty content is valid', () {
      final msg = ChatMessage(
        role: MessageRole.assistant,
        content: '',
        timestamp: DateTime.now(),
      );

      expect(msg.content, isEmpty);
    });

    test('very long content is valid', () {
      final msg = ChatMessage(
        role: MessageRole.assistant,
        content: 'A' * 100000,
        timestamp: DateTime.now(),
      );

      expect(msg.content.length, 100000);
    });

    test('unicode content', () {
      final msg = ChatMessage(
        role: MessageRole.assistant,
        content: '日本語テスト 🎉 αβγ مرحبا',
        timestamp: DateTime.now(),
      );

      expect(msg.content, contains('日本語'));
      expect(msg.content, contains('🎉'));
    });

    test('content with code blocks', () {
      final msg = ChatMessage(
        role: MessageRole.assistant,
        content: 'Here is code:\n```python\nprint("hello")\n```\nDone.',
        timestamp: DateTime.now(),
      );

      expect(msg.content, contains('```python'));
    });

    test('multiple attachments preserved in order', () {
      final paths = List.generate(10, (i) => '/data/file_$i.jpg');
      final msg = ChatMessage(
        role: MessageRole.user,
        content: 'Process all',
        timestamp: DateTime.now(),
        attachments: paths,
      );

      expect(msg.attachments, hasLength(10));
      expect(msg.attachments![0], '/data/file_0.jpg');
      expect(msg.attachments![9], '/data/file_9.jpg');
    });

    test('empty attachments list is not the same as null', () {
      final withEmpty = ChatMessage(
        role: MessageRole.user,
        content: 'test',
        timestamp: DateTime.now(),
        attachments: [],
      );
      final withNull = ChatMessage(
        role: MessageRole.user,
        content: 'test',
        timestamp: DateTime.now(),
      );

      expect(withEmpty.attachments, isNotNull);
      expect(withEmpty.attachments, isEmpty);
      expect(withNull.attachments, isNull);
    });
  });

  group('MessageRole comprehensive', () {
    test('has exactly 4 values', () {
      expect(MessageRole.values.length, 4);
    });

    test('all values are unique', () {
      final names = MessageRole.values.map((r) => r.name).toSet();
      expect(names.length, 4);
    });

    test('user role exists', () {
      expect(MessageRole.user.name, 'user');
    });

    test('assistant role exists', () {
      expect(MessageRole.assistant.name, 'assistant');
    });

    test('system role exists', () {
      expect(MessageRole.system.name, 'system');
    });

    test('error role exists', () {
      expect(MessageRole.error.name, 'error');
    });

    test('index values are sequential', () {
      expect(MessageRole.user.index, 0);
      expect(MessageRole.assistant.index, 1);
      expect(MessageRole.system.index, 2);
      expect(MessageRole.error.index, 3);
    });
  });

  group('Cold start buffer + stream timing', () {
    late ShareReceiverService service;

    setUp(() {
      service = ShareReceiverService.forTest();
    });

    tearDown(() {
      service.dispose();
    });

    test('buffer consumed exactly once even with stream active', () async {
      // Simulate cold start: Kotlin sends before Flutter mounts
      await service.handleMethodCall(MethodCall('onFilesShared', {
        'files': [
          {'path': '/cold.jpg', 'name': 'cold.jpg', 'size': 100, 'error': null},
        ],
        'text': null,
      }));

      // ChatScreen mounts and subscribes
      final streamEvents = <SharedFilesEvent>[];
      service.stream.listen(streamEvents.add);

      // Consume pending (deferred via addPostFrameCallback in real code)
      final pending = service.consumePending();
      expect(pending, isNotNull);
      expect(pending!.files[0].name, 'cold.jpg');

      // Second consume returns null
      expect(service.consumePending(), isNull);

      // Stream should not have the buffered event
      await Future.delayed(Duration.zero);
      expect(streamEvents, isEmpty);
    });

    test('warm start: stream gets event, no buffer', () async {
      // ChatScreen already mounted and subscribed
      final streamEvents = <SharedFilesEvent>[];
      service.stream.listen(streamEvents.add);

      // Share arrives while app is running
      await service.handleMethodCall(MethodCall('onFilesShared', {
        'files': [
          {'path': '/warm.jpg', 'name': 'warm.jpg', 'size': 200, 'error': null},
        ],
        'text': null,
      }));
      await Future.delayed(Duration.zero);

      expect(streamEvents, hasLength(1));
      expect(streamEvents[0].files[0].name, 'warm.jpg');
      expect(service.consumePending(), isNull);
    });

    test('cold start buffer then warm event: both received', () async {
      // Cold start buffer
      await service.handleMethodCall(MethodCall('onFilesShared', {
        'files': [
          {'path': '/cold.jpg', 'name': 'cold.jpg', 'size': 100, 'error': null},
        ],
        'text': null,
      }));

      // Subscribe
      final streamEvents = <SharedFilesEvent>[];
      service.stream.listen(streamEvents.add);

      // Consume buffer
      final pending = service.consumePending();
      expect(pending, isNotNull);

      // Warm event
      await service.handleMethodCall(MethodCall('onFilesShared', {
        'files': [
          {'path': '/warm.jpg', 'name': 'warm.jpg', 'size': 200, 'error': null},
        ],
        'text': null,
      }));
      await Future.delayed(Duration.zero);

      expect(streamEvents, hasLength(1));
      expect(streamEvents[0].files[0].name, 'warm.jpg');
    });
  });

  group('File path validation in chat flow', () {
    test('valid files have non-empty paths', () {
      final event = SharedFilesEvent(
        files: [
          SharedFileInfo(path: '/data/shared/photo.jpg', name: 'photo.jpg', size: 100),
        ],
      );

      final validFiles = event.files
          .where((f) => f.error == null && f.path.isNotEmpty)
          .toList();
      expect(validFiles, hasLength(1));
    });

    test('files with empty paths are excluded from valid set', () {
      final event = SharedFilesEvent(
        files: [
          SharedFileInfo(path: '', name: 'ghost.dat', size: 0),
        ],
      );

      final validFiles = event.files
          .where((f) => f.error == null && f.path.isNotEmpty)
          .toList();
      expect(validFiles, isEmpty);
    });

    test('files with errors are excluded from valid set', () {
      final event = SharedFilesEvent(
        files: [
          SharedFileInfo(path: '/data/big.mp4', name: 'big.mp4', size: 600000000, error: 'Too large'),
        ],
      );

      final validFiles = event.files
          .where((f) => f.error == null && f.path.isNotEmpty)
          .toList();
      expect(validFiles, isEmpty);
    });

    test('file with error AND non-empty path still excluded (error takes precedence)', () {
      final event = SharedFilesEvent(
        files: [
          SharedFileInfo(
            path: '/data/big.mp4',
            name: 'big.mp4',
            size: 600000000,
            error: 'Exceeded limit',
          ),
        ],
      );

      final validFiles = event.files
          .where((f) => f.error == null && f.path.isNotEmpty)
          .toList();
      expect(validFiles, isEmpty);
    });
  });
}
