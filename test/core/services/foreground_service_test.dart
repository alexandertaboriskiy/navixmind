import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navixmind/core/services/foreground_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ForegroundService', () {
    late List<MethodCall> methodCalls;

    setUp(() {
      methodCalls = [];

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('ai.navixmind/foreground_service'),
        (MethodCall methodCall) async {
          methodCalls.add(methodCall);
          return null;
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('ai.navixmind/foreground_service'),
        null,
      );
    });

    group('startTask', () {
      test('calls platform channel with correct method', () async {
        await ForegroundService.startTask('task-123', 'Processing video');

        expect(methodCalls.length, equals(1));
        expect(methodCalls.first.method, equals('startTask'));
      });

      test('passes taskId and title to platform', () async {
        await ForegroundService.startTask('my-task', 'Converting file');

        final args = methodCalls.first.arguments as Map<dynamic, dynamic>;
        expect(args['taskId'], equals('my-task'));
        expect(args['title'], equals('Converting file'));
      });

      test('handles empty taskId', () async {
        await ForegroundService.startTask('', 'Test');

        final args = methodCalls.first.arguments as Map<dynamic, dynamic>;
        expect(args['taskId'], equals(''));
      });

      test('handles special characters in title', () async {
        await ForegroundService.startTask('task', 'Processing: 50% done!');

        final args = methodCalls.first.arguments as Map<dynamic, dynamic>;
        expect(args['title'], equals('Processing: 50% done!'));
      });

      test('throws ForegroundServiceException on platform error', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('ai.navixmind/foreground_service'),
          (MethodCall methodCall) async {
            throw PlatformException(code: 'ERROR', message: 'Service unavailable');
          },
        );

        expect(
          () => ForegroundService.startTask('task', 'Test'),
          throwsA(isA<ForegroundServiceException>()),
        );
      });

      test('exception message contains platform error', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('ai.navixmind/foreground_service'),
          (MethodCall methodCall) async {
            throw PlatformException(code: 'ERROR', message: 'Battery saver active');
          },
        );

        try {
          await ForegroundService.startTask('task', 'Test');
          fail('Should have thrown');
        } catch (e) {
          expect(e.toString(), contains('Battery saver active'));
        }
      });
    });

    group('updateProgress', () {
      test('calls platform channel with correct method', () async {
        await ForegroundService.updateProgress('task-123', 50, 'Halfway done');

        expect(methodCalls.length, equals(1));
        expect(methodCalls.first.method, equals('updateProgress'));
      });

      test('passes all parameters correctly', () async {
        await ForegroundService.updateProgress('my-task', 75, 'Almost there');

        final args = methodCalls.first.arguments as Map<dynamic, dynamic>;
        expect(args['taskId'], equals('my-task'));
        expect(args['progress'], equals(75));
        expect(args['message'], equals('Almost there'));
      });

      test('handles 0% progress', () async {
        await ForegroundService.updateProgress('task', 0, 'Starting');

        final args = methodCalls.first.arguments as Map<dynamic, dynamic>;
        expect(args['progress'], equals(0));
      });

      test('handles 100% progress', () async {
        await ForegroundService.updateProgress('task', 100, 'Complete');

        final args = methodCalls.first.arguments as Map<dynamic, dynamic>;
        expect(args['progress'], equals(100));
      });

      test('throws ForegroundServiceException on platform error', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('ai.navixmind/foreground_service'),
          (MethodCall methodCall) async {
            throw PlatformException(code: 'ERROR', message: 'Task not found');
          },
        );

        expect(
          () => ForegroundService.updateProgress('task', 50, 'Test'),
          throwsA(isA<ForegroundServiceException>()),
        );
      });
    });

    group('stopTask', () {
      test('calls platform channel with correct method', () async {
        await ForegroundService.stopTask();

        expect(methodCalls.length, equals(1));
        expect(methodCalls.first.method, equals('stopTask'));
      });

      test('has no arguments', () async {
        await ForegroundService.stopTask();

        expect(methodCalls.first.arguments, isNull);
      });

      test('throws ForegroundServiceException on platform error', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('ai.navixmind/foreground_service'),
          (MethodCall methodCall) async {
            throw PlatformException(code: 'ERROR', message: 'Already stopped');
          },
        );

        expect(
          () => ForegroundService.stopTask(),
          throwsA(isA<ForegroundServiceException>()),
        );
      });

      test('can be called multiple times', () async {
        await ForegroundService.stopTask();
        await ForegroundService.stopTask();
        await ForegroundService.stopTask();

        expect(methodCalls.length, equals(3));
      });
    });

    group('full workflow', () {
      test('start, update progress, and stop', () async {
        await ForegroundService.startTask('video-1', 'Processing video');
        await ForegroundService.updateProgress('video-1', 25, 'Analyzing');
        await ForegroundService.updateProgress('video-1', 50, 'Converting');
        await ForegroundService.updateProgress('video-1', 75, 'Finalizing');
        await ForegroundService.updateProgress('video-1', 100, 'Done');
        await ForegroundService.stopTask();

        expect(methodCalls.length, equals(6));
        expect(methodCalls[0].method, equals('startTask'));
        expect(methodCalls[1].method, equals('updateProgress'));
        expect(methodCalls[5].method, equals('stopTask'));
      });
    });
  });

  group('ForegroundServiceException', () {
    test('stores message correctly', () {
      final exception = ForegroundServiceException('Test error');
      expect(exception.message, equals('Test error'));
    });

    test('toString includes message', () {
      final exception = ForegroundServiceException('Something went wrong');
      expect(exception.toString(), contains('Something went wrong'));
      expect(exception.toString(), contains('ForegroundServiceException'));
    });

    test('is an Exception', () {
      final exception = ForegroundServiceException('Test');
      expect(exception, isA<Exception>());
    });
  });
}
