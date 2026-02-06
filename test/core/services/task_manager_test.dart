import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navixmind/core/services/task_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock platform channels for Workmanager and ForegroundService
  setUpAll(() {
    // Mock the workmanager channels (there are multiple)
    const workmanagerChannels = [
      'be.tramckrijte.workmanager/foreground_channel',
      'be.tramckrijte.workmanager/foreground_channel_work_manager',
      'be.tramckrijte.workmanager/background_channel_work_manager',
    ];

    for (final channel in workmanagerChannels) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        MethodChannel(channel),
        (MethodCall methodCall) async {
          // Return appropriate values for different methods
          switch (methodCall.method) {
            case 'registerOneOffTask':
            case 'registerPeriodicTask':
            case 'cancelByUniqueName':
            case 'cancelAll':
              return true;
            case 'initialize':
              return null;
            default:
              return null;
          }
        },
      );
    }

    // Mock the foreground service channel
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('ai.navixmind/foreground_service'),
      (MethodCall methodCall) async {
        return null;
      },
    );
  });

  tearDownAll(() {
    const workmanagerChannels = [
      'be.tramckrijte.workmanager/foreground_channel',
      'be.tramckrijte.workmanager/foreground_channel_work_manager',
      'be.tramckrijte.workmanager/background_channel_work_manager',
    ];

    for (final channel in workmanagerChannels) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        MethodChannel(channel),
        null,
      );
    }

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('ai.navixmind/foreground_service'),
      null,
    );
  });

  group('TaskType', () {
    test('has all expected types', () {
      expect(TaskType.values, contains(TaskType.ffmpegProcess));
      expect(TaskType.values, contains(TaskType.largeDownload));
      expect(TaskType.values, contains(TaskType.batchProcess));
      expect(TaskType.values, contains(TaskType.apiSync));
    });

    test('has exactly 4 types', () {
      expect(TaskType.values.length, equals(4));
    });
  });

  group('TaskStatus', () {
    test('has all expected statuses', () {
      expect(TaskStatus.values, contains(TaskStatus.pending));
      expect(TaskStatus.values, contains(TaskStatus.running));
      expect(TaskStatus.values, contains(TaskStatus.completed));
      expect(TaskStatus.values, contains(TaskStatus.failed));
      expect(TaskStatus.values, contains(TaskStatus.cancelled));
    });

    test('has exactly 5 statuses', () {
      expect(TaskStatus.values.length, equals(5));
    });
  });

  group('TaskProgress', () {
    test('creates with required fields', () {
      final progress = TaskProgress(
        taskId: 'task-123',
        status: TaskStatus.running,
      );

      expect(progress.taskId, equals('task-123'));
      expect(progress.status, equals(TaskStatus.running));
      expect(progress.progress, equals(0.0));
      expect(progress.message, isNull);
      expect(progress.error, isNull);
    });

    test('creates with all fields', () {
      final progress = TaskProgress(
        taskId: 'task-456',
        status: TaskStatus.running,
        progress: 0.75,
        message: 'Processing...',
        error: null,
      );

      expect(progress.taskId, equals('task-456'));
      expect(progress.status, equals(TaskStatus.running));
      expect(progress.progress, equals(0.75));
      expect(progress.message, equals('Processing...'));
    });

    test('creates with error field', () {
      final progress = TaskProgress(
        taskId: 'task-789',
        status: TaskStatus.failed,
        progress: 0.5,
        error: 'Network error',
      );

      expect(progress.status, equals(TaskStatus.failed));
      expect(progress.error, equals('Network error'));
    });

    test('progress defaults to 0.0', () {
      final progress = TaskProgress(
        taskId: 'task-default',
        status: TaskStatus.pending,
      );

      expect(progress.progress, equals(0.0));
    });
  });

  group('CancellationToken', () {
    test('starts not cancelled', () {
      final token = CancellationToken();
      expect(token.isCancelled, isFalse);
    });

    test('can be cancelled', () {
      final token = CancellationToken();
      token.cancel();
      expect(token.isCancelled, isTrue);
    });

    test('stays cancelled after cancel', () {
      final token = CancellationToken();
      token.cancel();
      expect(token.isCancelled, isTrue);
      // Still cancelled on subsequent checks
      expect(token.isCancelled, isTrue);
    });
  });

  group('TaskManager', () {
    late TaskManager taskManager;

    setUp(() {
      // Access the singleton instance
      taskManager = TaskManager.instance;
    });

    group('singleton', () {
      test('returns same instance', () {
        final instance1 = TaskManager.instance;
        final instance2 = TaskManager.instance;
        expect(identical(instance1, instance2), isTrue);
      });
    });

    group('startTask', () {
      test('starts ffmpegProcess task and returns taskId', () async {
        final taskId = await taskManager.startTask(
          TaskType.ffmpegProcess,
          {'input': 'video.mp4', 'output': 'output.mp4'},
        );

        expect(taskId, isNotEmpty);
        expect(taskId.length, equals(36)); // UUID v4 format
      });

      test('starts largeDownload task', () async {
        final taskId = await taskManager.startTask(
          TaskType.largeDownload,
          {'url': 'https://example.com/file.zip'},
        );

        expect(taskId, isNotEmpty);
      });

      test('starts batchProcess task', () async {
        final taskId = await taskManager.startTask(
          TaskType.batchProcess,
          {'items': [1, 2, 3]},
        );

        expect(taskId, isNotEmpty);
      });

      test('starts apiSync task', () async {
        final taskId = await taskManager.startTask(
          TaskType.apiSync,
          {'endpoint': '/sync'},
        );

        expect(taskId, isNotEmpty);
      });

      test('starts task with description', () async {
        final taskId = await taskManager.startTask(
          TaskType.ffmpegProcess,
          {'input': 'video.mp4'},
          description: 'Converting video to MP4',
        );

        expect(taskId, isNotEmpty);
        final task = taskManager.getTask(taskId);
        expect(task, isNotNull);
      });

      test('generates unique task IDs', () async {
        final taskId1 = await taskManager.startTask(
          TaskType.apiSync,
          {},
        );
        final taskId2 = await taskManager.startTask(
          TaskType.apiSync,
          {},
        );

        expect(taskId1, isNot(equals(taskId2)));
      });
    });

    group('progressStream', () {
      test('emits running status when task starts', () async {
        final events = <TaskProgress>[];
        final subscription = taskManager.progressStream.listen((event) {
          events.add(event);
        });

        final taskId = await taskManager.startTask(
          TaskType.largeDownload,
          {
            'url': 'https://example.com/file.zip',
            'output_path': '/tmp/download.zip',
          },
        );

        await Future.delayed(const Duration(milliseconds: 150));

        expect(events.any((e) => e.taskId == taskId && e.status == TaskStatus.running), isTrue);

        await subscription.cancel();
      });

      test('is a broadcast stream', () {
        expect(taskManager.progressStream.isBroadcast, isTrue);
      });

      test('multiple listeners receive events', () async {
        final events1 = <TaskProgress>[];
        final events2 = <TaskProgress>[];

        final sub1 = taskManager.progressStream.listen((e) => events1.add(e));
        final sub2 = taskManager.progressStream.listen((e) => events2.add(e));

        await taskManager.startTask(TaskType.largeDownload, {'url': 'https://example.com/f.zip', 'output_path': '/tmp/d.zip'});

        await Future.delayed(const Duration(milliseconds: 50));

        expect(events1.isNotEmpty, isTrue);
        expect(events2.isNotEmpty, isTrue);
        expect(events1.length, equals(events2.length));

        await sub1.cancel();
        await sub2.cancel();
      });
    });

    group('watchTask', () {
      test('filters events for specific taskId', () async {
        // Start a long-running task first to get its ID
        final taskId1 = await taskManager.startTask(TaskType.ffmpegProcess, {'input': 'video.mp4'});

        // Subscribe to watch this task's future events
        final watchedEvents = <TaskProgress>[];
        final subscription = taskManager.watchTask(taskId1).listen((event) {
          watchedEvents.add(event);
        });

        // Start another task that should not be included
        await taskManager.startTask(TaskType.apiSync, {});

        // Wait for FFmpeg task to emit more events (it emits every 100ms)
        await Future.delayed(const Duration(milliseconds: 500));

        expect(watchedEvents.isNotEmpty, isTrue);
        expect(watchedEvents.every((e) => e.taskId == taskId1), isTrue);

        await subscription.cancel();
      });

      test('does not receive events from other tasks', () async {
        final task1Events = <TaskProgress>[];
        final task2Events = <TaskProgress>[];

        final taskId1 = await taskManager.startTask(TaskType.largeDownload, {'url': 'https://example.com/f.zip', 'output_path': '/tmp/d.zip'});
        final taskId2 = await taskManager.startTask(TaskType.apiSync, {});

        final sub1 = taskManager.watchTask(taskId1).listen((e) => task1Events.add(e));
        final sub2 = taskManager.watchTask(taskId2).listen((e) => task2Events.add(e));

        await Future.delayed(const Duration(milliseconds: 50));

        expect(task1Events.every((e) => e.taskId == taskId1), isTrue);
        expect(task2Events.every((e) => e.taskId == taskId2), isTrue);

        await sub1.cancel();
        await sub2.cancel();
      });
    });

    group('getTask', () {
      test('returns task info for existing task', () async {
        final taskId = await taskManager.startTask(
          TaskType.batchProcess,
          {'data': 'test'},
        );

        final task = taskManager.getTask(taskId);

        expect(task, isNotNull);
      });

      test('returns null for non-existent task', () {
        final task = taskManager.getTask('non-existent-task-id');
        expect(task, isNull);
      });

      test('returns null for invalid taskId', () {
        final task = taskManager.getTask('');
        expect(task, isNull);
      });
    });

    group('cancelTask', () {
      test('cancels running task', () async {
        final events = <TaskProgress>[];
        final subscription = taskManager.progressStream.listen((e) => events.add(e));

        final taskId = await taskManager.startTask(
          TaskType.ffmpegProcess,
          {'input': 'video.mp4'},
        );

        await taskManager.cancelTask(taskId);

        await Future.delayed(const Duration(milliseconds: 50));

        expect(
          events.any((e) => e.taskId == taskId && e.status == TaskStatus.cancelled),
          isTrue,
        );

        await subscription.cancel();
      });

      test('emits cancelled status with message', () async {
        final events = <TaskProgress>[];
        final subscription = taskManager.progressStream.listen((e) => events.add(e));

        final taskId = await taskManager.startTask(TaskType.largeDownload, {'url': 'https://example.com/f.zip', 'output_path': '/tmp/d.zip'});
        await taskManager.cancelTask(taskId);

        await Future.delayed(const Duration(milliseconds: 50));

        final cancelledEvent = events.firstWhere(
          (e) => e.taskId == taskId && e.status == TaskStatus.cancelled,
        );
        expect(cancelledEvent.message, equals('Cancelled'));

        await subscription.cancel();
      });

      test('removes task from manager after cancellation', () async {
        final taskId = await taskManager.startTask(TaskType.apiSync, {});

        await taskManager.cancelTask(taskId);

        final task = taskManager.getTask(taskId);
        expect(task, isNull);
      });

      test('does not throw for non-existent task', () async {
        // Should complete without throwing
        await taskManager.cancelTask('non-existent-task');
      });

      test('does not throw for empty taskId', () async {
        // Should complete without throwing
        await taskManager.cancelTask('');
      });
    });

    group('task status progression', () {
      test('progresses from pending to running', () async {
        final events = <TaskProgress>[];
        final subscription = taskManager.progressStream.listen((e) => events.add(e));

        final taskId = await taskManager.startTask(TaskType.largeDownload, {'url': 'https://example.com/f.zip', 'output_path': '/tmp/d.zip'});

        await Future.delayed(const Duration(milliseconds: 50));

        final runningEvents = events.where(
          (e) => e.taskId == taskId && e.status == TaskStatus.running,
        );
        expect(runningEvents.isNotEmpty, isTrue);

        await subscription.cancel();
      });

      test('progresses to completed for largeDownload', () async {
        final events = <TaskProgress>[];
        final subscription = taskManager.progressStream.listen((e) => events.add(e));

        final taskId = await taskManager.startTask(TaskType.largeDownload, {'url': 'https://example.com/f.zip', 'output_path': '/tmp/d.zip'});

        // Wait enough time for the download task to complete (100ms delay + processing)
        await Future.delayed(const Duration(milliseconds: 300));

        final completedEvents = events.where(
          (e) => e.taskId == taskId && e.status == TaskStatus.completed,
        );
        expect(completedEvents.isNotEmpty, isTrue);

        await subscription.cancel();
      });

      test('progresses to completed for batchProcess', () async {
        final events = <TaskProgress>[];
        final subscription = taskManager.progressStream.listen((e) => events.add(e));

        final taskId = await taskManager.startTask(TaskType.batchProcess, {});

        await Future.delayed(const Duration(milliseconds: 100));

        expect(
          events.any((e) => e.taskId == taskId && e.status == TaskStatus.completed),
          isTrue,
        );

        await subscription.cancel();
      });

      test('progresses to completed for apiSync', () async {
        final events = <TaskProgress>[];
        final subscription = taskManager.progressStream.listen((e) => events.add(e));

        final taskId = await taskManager.startTask(TaskType.apiSync, {});

        await Future.delayed(const Duration(milliseconds: 100));

        expect(
          events.any((e) => e.taskId == taskId && e.status == TaskStatus.completed),
          isTrue,
        );

        await subscription.cancel();
      });
    });

    group('FFmpeg simulation progress updates', () {
      test('emits progress updates from 0 to 100%', () async {
        final events = <TaskProgress>[];
        final subscription = taskManager.progressStream.listen((e) => events.add(e));

        final taskId = await taskManager.startTask(
          TaskType.ffmpegProcess,
          {'input': 'video.mp4'},
        );

        // Wait for FFmpeg simulation to complete (11 iterations * 100ms each + buffer)
        await Future.delayed(const Duration(milliseconds: 1500));

        final ffmpegEvents = events.where((e) => e.taskId == taskId).toList();

        // Should have multiple progress updates
        expect(ffmpegEvents.length, greaterThan(5));

        // Should have running status events with progress
        final runningEvents = ffmpegEvents.where((e) => e.status == TaskStatus.running).toList();
        expect(runningEvents.isNotEmpty, isTrue);

        // Should end with completed status
        expect(ffmpegEvents.last.status, equals(TaskStatus.completed));

        await subscription.cancel();
      });

      test('final progress is 1.0 on completion', () async {
        final events = <TaskProgress>[];
        final subscription = taskManager.progressStream.listen((e) => events.add(e));

        final taskId = await taskManager.startTask(
          TaskType.ffmpegProcess,
          {'input': 'video.mp4'},
        );

        await Future.delayed(const Duration(milliseconds: 1500));

        final ffmpegEvents = events.where((e) => e.taskId == taskId).toList();
        final completedEvent = ffmpegEvents.firstWhere(
          (e) => e.status == TaskStatus.completed,
        );

        expect(completedEvent.progress, equals(1.0));

        await subscription.cancel();
      });

      test('includes progress message with percentage', () async {
        final events = <TaskProgress>[];
        final subscription = taskManager.progressStream.listen((e) => events.add(e));

        final taskId = await taskManager.startTask(
          TaskType.ffmpegProcess,
          {'input': 'video.mp4'},
        );

        await Future.delayed(const Duration(milliseconds: 1500));

        final ffmpegEvents = events.where((e) => e.taskId == taskId).toList();
        final progressMessages = ffmpegEvents
            .where((e) => e.message != null && e.message!.contains('%'))
            .toList();

        expect(progressMessages.isNotEmpty, isTrue);
        // Check for processing message (stub uses "Processing..." format)
        expect(progressMessages.any((e) => e.message!.contains('Processing')), isTrue);

        await subscription.cancel();
      });

      test('progress values are between 0 and 1', () async {
        final events = <TaskProgress>[];
        final subscription = taskManager.progressStream.listen((e) => events.add(e));

        final taskId = await taskManager.startTask(
          TaskType.ffmpegProcess,
          {'input': 'video.mp4'},
        );

        await Future.delayed(const Duration(milliseconds: 1500));

        final ffmpegEvents = events.where((e) => e.taskId == taskId).toList();

        for (final event in ffmpegEvents) {
          expect(event.progress, greaterThanOrEqualTo(0.0));
          expect(event.progress, lessThanOrEqualTo(1.0));
        }

        await subscription.cancel();
      });
    });

    group('multiple concurrent tasks', () {
      test('handles multiple tasks simultaneously', () async {
        final events = <TaskProgress>[];
        final subscription = taskManager.progressStream.listen((e) => events.add(e));

        final taskId1 = await taskManager.startTask(TaskType.largeDownload, {'url': 'https://example.com/f.zip', 'output_path': '/tmp/d.zip'});
        final taskId2 = await taskManager.startTask(TaskType.apiSync, {});
        final taskId3 = await taskManager.startTask(TaskType.batchProcess, {});

        await Future.delayed(const Duration(milliseconds: 100));

        final task1Events = events.where((e) => e.taskId == taskId1);
        final task2Events = events.where((e) => e.taskId == taskId2);
        final task3Events = events.where((e) => e.taskId == taskId3);

        expect(task1Events.isNotEmpty, isTrue);
        expect(task2Events.isNotEmpty, isTrue);
        expect(task3Events.isNotEmpty, isTrue);

        await subscription.cancel();
      });

      test('all concurrent tasks can complete', () async {
        final events = <TaskProgress>[];
        final subscription = taskManager.progressStream.listen((e) => events.add(e));

        final taskId1 = await taskManager.startTask(TaskType.largeDownload, {'url': 'https://example.com/f.zip', 'output_path': '/tmp/d.zip'});
        final taskId2 = await taskManager.startTask(TaskType.apiSync, {});
        final taskId3 = await taskManager.startTask(TaskType.batchProcess, {});

        await Future.delayed(const Duration(milliseconds: 200));

        expect(
          events.any((e) => e.taskId == taskId1 && e.status == TaskStatus.completed),
          isTrue,
        );
        expect(
          events.any((e) => e.taskId == taskId2 && e.status == TaskStatus.completed),
          isTrue,
        );
        expect(
          events.any((e) => e.taskId == taskId3 && e.status == TaskStatus.completed),
          isTrue,
        );

        await subscription.cancel();
      });

      test('concurrent FFmpeg tasks run independently', () async {
        final events = <TaskProgress>[];
        final subscription = taskManager.progressStream.listen((e) => events.add(e));

        final taskId1 = await taskManager.startTask(
          TaskType.ffmpegProcess,
          {'input': 'video1.mp4'},
        );
        final taskId2 = await taskManager.startTask(
          TaskType.ffmpegProcess,
          {'input': 'video2.mp4'},
        );

        await Future.delayed(const Duration(milliseconds: 1500));

        final task1Events = events.where((e) => e.taskId == taskId1).toList();
        final task2Events = events.where((e) => e.taskId == taskId2).toList();

        // Both tasks should have progress updates
        expect(task1Events.length, greaterThan(5));
        expect(task2Events.length, greaterThan(5));

        // Both should complete
        expect(task1Events.last.status, equals(TaskStatus.completed));
        expect(task2Events.last.status, equals(TaskStatus.completed));

        await subscription.cancel();
      });
    });

    group('edge cases', () {
      test('handles empty params', () async {
        final taskId = await taskManager.startTask(TaskType.apiSync, {});
        expect(taskId, isNotEmpty);
      });

      test('handles params with various types', () async {
        // WorkManager only supports: int, bool, double, String, and their lists
        final taskId = await taskManager.startTask(
          TaskType.batchProcess,
          {
            'string': 'value',
            'int': 42,
            'double': 3.14,
            'bool': true,
            'intList': [1, 2, 3],
            'stringList': ['a', 'b', 'c'],
          },
        );
        expect(taskId, isNotEmpty);
      });

      test('getTask returns null for random UUID', () {
        final task = taskManager.getTask('550e8400-e29b-41d4-a716-446655440000');
        expect(task, isNull);
      });

      test('watchTask returns empty stream for non-existent task', () async {
        final events = <TaskProgress>[];
        final subscription = taskManager.watchTask('non-existent').listen((e) {
          events.add(e);
        });

        // Start a different task
        await taskManager.startTask(TaskType.apiSync, {});

        await Future.delayed(const Duration(milliseconds: 100));

        // Should not have received any events for the non-existent task
        expect(events, isEmpty);

        await subscription.cancel();
      });

      test('cancel already completed task does not throw', () async {
        final taskId = await taskManager.startTask(TaskType.largeDownload, {'url': 'https://example.com/f.zip', 'output_path': '/tmp/d.zip'});

        // Wait for completion
        await Future.delayed(const Duration(milliseconds: 100));

        // Cancel after completion - should not throw
        await taskManager.cancelTask(taskId);
      });

      test('multiple cancellations of same task do not throw', () async {
        final taskId = await taskManager.startTask(TaskType.apiSync, {});

        await taskManager.cancelTask(taskId);
        await taskManager.cancelTask(taskId);
        await taskManager.cancelTask(taskId);

        // Should complete without throwing
      });
    });

    group('task status on failure', () {
      test('TaskProgress can represent failed status', () {
        final progress = TaskProgress(
          taskId: 'failed-task',
          status: TaskStatus.failed,
          progress: 0.5,
          error: 'Processing error occurred',
        );

        expect(progress.status, equals(TaskStatus.failed));
        expect(progress.error, equals('Processing error occurred'));
        expect(progress.progress, equals(0.5));
      });

      test('failed task includes error message', () {
        final progress = TaskProgress(
          taskId: 'error-task',
          status: TaskStatus.failed,
          error: 'Network timeout',
        );

        expect(progress.error, isNotNull);
        expect(progress.error, contains('timeout'));
      });
    });

    group('stream behavior', () {
      test('late listener receives new events', () async {
        final earlyEvents = <TaskProgress>[];
        final lateEvents = <TaskProgress>[];

        final earlySub = taskManager.progressStream.listen((e) => earlyEvents.add(e));

        await taskManager.startTask(TaskType.apiSync, {});
        await Future.delayed(const Duration(milliseconds: 50));

        // Late listener joins
        final lateSub = taskManager.progressStream.listen((e) => lateEvents.add(e));

        await taskManager.startTask(TaskType.largeDownload, {'url': 'https://example.com/f.zip', 'output_path': '/tmp/d.zip'});
        await Future.delayed(const Duration(milliseconds: 50));

        // Early listener has events from both tasks
        expect(earlyEvents.isNotEmpty, isTrue);

        // Late listener only has events after subscription
        // (broadcast stream does not replay old events)
        expect(lateEvents.isNotEmpty, isTrue);

        await earlySub.cancel();
        await lateSub.cancel();
      });

      test('stream continues after listener cancellation', () async {
        final events1 = <TaskProgress>[];
        final events2 = <TaskProgress>[];

        final sub1 = taskManager.progressStream.listen((e) => events1.add(e));

        await taskManager.startTask(TaskType.apiSync, {});
        await Future.delayed(const Duration(milliseconds: 50));

        await sub1.cancel();

        final sub2 = taskManager.progressStream.listen((e) => events2.add(e));

        await taskManager.startTask(TaskType.largeDownload, {'url': 'https://example.com/f.zip', 'output_path': '/tmp/d.zip'});
        await Future.delayed(const Duration(milliseconds: 50));

        expect(events1.isNotEmpty, isTrue);
        expect(events2.isNotEmpty, isTrue);

        await sub2.cancel();
      });
    });
  });

  group('Task workflow integration', () {
    late TaskManager taskManager;

    setUp(() {
      taskManager = TaskManager.instance;
    });

    test('complete workflow: start -> progress -> complete', () async {
      final events = <TaskProgress>[];
      final statuses = <TaskStatus>[];

      final subscription = taskManager.progressStream.listen((event) {
        events.add(event);
        statuses.add(event.status);
      });

      final taskId = await taskManager.startTask(
        TaskType.ffmpegProcess,
        {'input': 'test.mp4'},
        description: 'Test conversion',
      );

      // Wait for full completion
      await Future.delayed(const Duration(milliseconds: 1500));

      final taskEvents = events.where((e) => e.taskId == taskId).toList();

      // Verify workflow
      expect(taskEvents.isNotEmpty, isTrue);
      expect(taskEvents.first.status, equals(TaskStatus.running));
      expect(taskEvents.last.status, equals(TaskStatus.completed));
      expect(taskEvents.last.progress, equals(1.0));

      await subscription.cancel();
    });

    test('complete workflow: start -> cancel', () async {
      final events = <TaskProgress>[];

      final subscription = taskManager.progressStream.listen((e) => events.add(e));

      final taskId = await taskManager.startTask(
        TaskType.ffmpegProcess,
        {'input': 'test.mp4'},
      );

      // Cancel quickly
      await Future.delayed(const Duration(milliseconds: 200));
      await taskManager.cancelTask(taskId);

      await Future.delayed(const Duration(milliseconds: 50));

      final taskEvents = events.where((e) => e.taskId == taskId).toList();

      // Verify cancellation
      expect(taskEvents.any((e) => e.status == TaskStatus.cancelled), isTrue);

      await subscription.cancel();
    });

    test('watchTask receives only relevant events during workflow', () async {
      final watchedEvents = <TaskProgress>[];

      final targetTaskId = await taskManager.startTask(
        TaskType.ffmpegProcess,
        {'input': 'target.mp4'},
      );

      final subscription = taskManager.watchTask(targetTaskId).listen((e) {
        watchedEvents.add(e);
      });

      // Start other tasks that should be filtered out
      await taskManager.startTask(TaskType.apiSync, {});
      await taskManager.startTask(TaskType.largeDownload, {'url': 'https://example.com/f.zip', 'output_path': '/tmp/d.zip'});

      await Future.delayed(const Duration(milliseconds: 1500));

      // All events should be for the target task
      expect(watchedEvents.every((e) => e.taskId == targetTaskId), isTrue);
      expect(watchedEvents.isNotEmpty, isTrue);

      await subscription.cancel();
    });
  });
}
