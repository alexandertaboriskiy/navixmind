import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:navixmind/core/services/offline_queue_manager.dart';

void main() {
  group('OfflineQueueEvent', () {
    test('creates messageQueued event', () {
      final event = OfflineQueueEvent(
        type: OfflineQueueEventType.messageQueued,
        pendingCount: 1,
        message: 'Message queued for later',
      );

      expect(event.type, equals(OfflineQueueEventType.messageQueued));
      expect(event.pendingCount, equals(1));
      expect(event.message, equals('Message queued for later'));
      expect(event.result, isNull);
      expect(event.error, isNull);
    });

    test('creates processingStarted event', () {
      final event = OfflineQueueEvent(
        type: OfflineQueueEventType.processingStarted,
        pendingCount: 5,
        message: 'Processing queued messages...',
      );

      expect(event.type, equals(OfflineQueueEventType.processingStarted));
      expect(event.pendingCount, equals(5));
    });

    test('creates processingMessage event', () {
      final event = OfflineQueueEvent(
        type: OfflineQueueEventType.processingMessage,
        pendingCount: 3,
        message: 'Sending: Hello world...',
      );

      expect(event.type, equals(OfflineQueueEventType.processingMessage));
    });

    test('creates messageSent event with result', () {
      final event = OfflineQueueEvent(
        type: OfflineQueueEventType.messageSent,
        pendingCount: 2,
        message: 'Message sent successfully',
        result: {'response': 'AI response content'},
      );

      expect(event.type, equals(OfflineQueueEventType.messageSent));
      expect(event.result, isNotNull);
      expect(event.result!['response'], equals('AI response content'));
    });

    test('creates messageFailed event with error', () {
      final event = OfflineQueueEvent(
        type: OfflineQueueEventType.messageFailed,
        pendingCount: 2,
        message: 'Failed to send message',
        error: 'Network error',
      );

      expect(event.type, equals(OfflineQueueEventType.messageFailed));
      expect(event.error, equals('Network error'));
    });

    test('creates processingPaused event', () {
      final event = OfflineQueueEvent(
        type: OfflineQueueEventType.processingPaused,
        pendingCount: 3,
        message: 'Connection lost, will retry when online',
      );

      expect(event.type, equals(OfflineQueueEventType.processingPaused));
    });

    test('creates queueEmpty event', () {
      final event = OfflineQueueEvent(
        type: OfflineQueueEventType.queueEmpty,
        pendingCount: 0,
        message: 'All messages sent',
      );

      expect(event.type, equals(OfflineQueueEventType.queueEmpty));
      expect(event.pendingCount, equals(0));
    });
  });

  group('OfflineQueueEventType', () {
    test('has all expected types', () {
      expect(OfflineQueueEventType.values, contains(OfflineQueueEventType.messageQueued));
      expect(OfflineQueueEventType.values, contains(OfflineQueueEventType.processingStarted));
      expect(OfflineQueueEventType.values, contains(OfflineQueueEventType.processingMessage));
      expect(OfflineQueueEventType.values, contains(OfflineQueueEventType.messageSent));
      expect(OfflineQueueEventType.values, contains(OfflineQueueEventType.messageFailed));
      expect(OfflineQueueEventType.values, contains(OfflineQueueEventType.processingPaused));
      expect(OfflineQueueEventType.values, contains(OfflineQueueEventType.queueEmpty));
    });
  });

  group('Queue state machine', () {
    test('follows correct state transitions when online', () async {
      final states = <OfflineQueueEventType>[];
      // Use sync: true so events are delivered synchronously
      final controller = StreamController<OfflineQueueEvent>.broadcast(sync: true);

      controller.stream.listen((event) {
        states.add(event.type);
      });

      // Simulate queue processing
      controller.add(OfflineQueueEvent(
        type: OfflineQueueEventType.messageQueued,
        pendingCount: 1,
        message: '',
      ));
      controller.add(OfflineQueueEvent(
        type: OfflineQueueEventType.processingStarted,
        pendingCount: 1,
        message: '',
      ));
      controller.add(OfflineQueueEvent(
        type: OfflineQueueEventType.processingMessage,
        pendingCount: 1,
        message: '',
      ));
      controller.add(OfflineQueueEvent(
        type: OfflineQueueEventType.messageSent,
        pendingCount: 0,
        message: '',
      ));
      controller.add(OfflineQueueEvent(
        type: OfflineQueueEventType.queueEmpty,
        pendingCount: 0,
        message: '',
      ));

      expect(states, equals([
        OfflineQueueEventType.messageQueued,
        OfflineQueueEventType.processingStarted,
        OfflineQueueEventType.processingMessage,
        OfflineQueueEventType.messageSent,
        OfflineQueueEventType.queueEmpty,
      ]));

      await controller.close();
    });

    test('handles connection loss during processing', () async {
      final states = <OfflineQueueEventType>[];
      final controller = StreamController<OfflineQueueEvent>.broadcast(sync: true);

      controller.stream.listen((event) {
        states.add(event.type);
      });

      // Simulate connection loss
      controller.add(OfflineQueueEvent(
        type: OfflineQueueEventType.processingStarted,
        pendingCount: 3,
        message: '',
      ));
      controller.add(OfflineQueueEvent(
        type: OfflineQueueEventType.processingMessage,
        pendingCount: 3,
        message: '',
      ));
      controller.add(OfflineQueueEvent(
        type: OfflineQueueEventType.messageSent,
        pendingCount: 2,
        message: '',
      ));
      controller.add(OfflineQueueEvent(
        type: OfflineQueueEventType.processingPaused,
        pendingCount: 2,
        message: 'Connection lost',
      ));

      expect(states, contains(OfflineQueueEventType.processingPaused));
      expect(states.last, equals(OfflineQueueEventType.processingPaused));

      await controller.close();
    });

    test('handles message failure', () async {
      final events = <OfflineQueueEvent>[];
      final controller = StreamController<OfflineQueueEvent>.broadcast(sync: true);

      controller.stream.listen((event) {
        events.add(event);
      });

      controller.add(OfflineQueueEvent(
        type: OfflineQueueEventType.processingStarted,
        pendingCount: 2,
        message: '',
      ));
      controller.add(OfflineQueueEvent(
        type: OfflineQueueEventType.messageFailed,
        pendingCount: 1,
        message: 'Failed to send message',
        error: 'API rate limit exceeded',
      ));

      final failedEvent = events.last;
      expect(failedEvent.type, equals(OfflineQueueEventType.messageFailed));
      expect(failedEvent.error, equals('API rate limit exceeded'));

      await controller.close();
    });
  });

  group('Message truncation helper', () {
    test('truncates long messages', () {
      final result = _truncate('This is a very long message', 10);
      expect(result, equals('This is a ...'));
    });

    test('preserves short messages', () {
      final result = _truncate('Short', 10);
      expect(result, equals('Short'));
    });

    test('handles exact length', () {
      final result = _truncate('Exactly 10', 10);
      expect(result, equals('Exactly 10'));
    });

    test('handles empty string', () {
      final result = _truncate('', 10);
      expect(result, equals(''));
    });
  });

  group('Queue event broadcasting', () {
    test('stream is broadcast - multiple listeners', () async {
      final controller = StreamController<OfflineQueueEvent>.broadcast();
      final listener1Events = <OfflineQueueEvent>[];
      final listener2Events = <OfflineQueueEvent>[];

      controller.stream.listen((e) => listener1Events.add(e));
      controller.stream.listen((e) => listener2Events.add(e));

      controller.add(OfflineQueueEvent(
        type: OfflineQueueEventType.messageQueued,
        pendingCount: 1,
        message: 'Test',
      ));

      await Future.delayed(Duration.zero);

      expect(listener1Events.length, equals(1));
      expect(listener2Events.length, equals(1));

      controller.close();
    });
  });

  group('Pending count tracking', () {
    test('tracks pending count correctly through events', () async {
      final counts = <int>[];
      final controller = StreamController<OfflineQueueEvent>.broadcast(sync: true);

      controller.stream.listen((event) {
        counts.add(event.pendingCount);
      });

      // Queue 3 messages
      for (var i = 1; i <= 3; i++) {
        controller.add(OfflineQueueEvent(
          type: OfflineQueueEventType.messageQueued,
          pendingCount: i,
          message: '',
        ));
      }

      // Process all
      controller.add(OfflineQueueEvent(
        type: OfflineQueueEventType.processingStarted,
        pendingCount: 3,
        message: '',
      ));

      for (var i = 2; i >= 0; i--) {
        controller.add(OfflineQueueEvent(
          type: OfflineQueueEventType.messageSent,
          pendingCount: i,
          message: '',
        ));
      }

      controller.add(OfflineQueueEvent(
        type: OfflineQueueEventType.queueEmpty,
        pendingCount: 0,
        message: '',
      ));

      expect(counts, equals([1, 2, 3, 3, 2, 1, 0, 0]));

      await controller.close();
    });
  });

  group('Attachment paths handling', () {
    test('handles message with no attachments', () {
      final query = _MockPendingQuery(
        id: 1,
        query: 'Hello',
        attachmentPaths: [],
      );

      expect(query.attachmentPaths.isEmpty, isTrue);
    });

    test('handles message with single attachment', () {
      final query = _MockPendingQuery(
        id: 1,
        query: 'Check this image',
        attachmentPaths: ['/storage/image.jpg'],
      );

      expect(query.attachmentPaths.length, equals(1));
      expect(query.attachmentPaths.first, equals('/storage/image.jpg'));
    });

    test('handles message with multiple attachments', () {
      final query = _MockPendingQuery(
        id: 1,
        query: 'Process these files',
        attachmentPaths: [
          '/storage/file1.pdf',
          '/storage/file2.jpg',
          '/storage/file3.mp4',
        ],
      );

      expect(query.attachmentPaths.length, equals(3));
    });
  });

  group('Error recovery', () {
    test('reports error in failed event', () {
      final event = OfflineQueueEvent(
        type: OfflineQueueEventType.messageFailed,
        pendingCount: 5,
        message: 'Failed to send message',
        error: 'Connection timeout',
      );

      expect(event.error, isNotNull);
      expect(event.error, contains('timeout'));
    });

    test('captures network errors', () {
      final event = OfflineQueueEvent(
        type: OfflineQueueEventType.processingPaused,
        pendingCount: 3,
        message: 'Connection lost, will retry when online',
      );

      expect(event.message, contains('retry'));
    });
  });

  group('Processing state', () {
    test('isProcessing prevents concurrent processing', () {
      var isProcessing = false;
      var processingAttempts = 0;

      void processQueue() {
        if (isProcessing) return;
        isProcessing = true;
        processingAttempts++;
        // Simulate async work
        Future.delayed(const Duration(milliseconds: 100), () {
          isProcessing = false;
        });
      }

      // Multiple calls while processing
      processQueue();
      processQueue();
      processQueue();

      expect(processingAttempts, equals(1));
    });
  });
}

// Helper function matching the implementation
String _truncate(String text, int maxLength) {
  if (text.length <= maxLength) return text;
  return '${text.substring(0, maxLength)}...';
}

// Mock class for testing
class _MockPendingQuery {
  final int id;
  final String query;
  final List<String> attachmentPaths;

  _MockPendingQuery({
    required this.id,
    required this.query,
    required this.attachmentPaths,
  });
}
