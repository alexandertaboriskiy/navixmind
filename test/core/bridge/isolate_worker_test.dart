import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:navixmind/core/bridge/isolate_worker.dart';

void main() {
  group('WorkerMessageType', () {
    test('has all expected enum values', () {
      expect(WorkerMessageType.values.length, equals(5));
      expect(WorkerMessageType.values, contains(WorkerMessageType.init));
      expect(WorkerMessageType.values, contains(WorkerMessageType.call));
      expect(WorkerMessageType.values, contains(WorkerMessageType.result));
      expect(WorkerMessageType.values, contains(WorkerMessageType.error));
      expect(WorkerMessageType.values, contains(WorkerMessageType.shutdown));
    });

    test('enum values have correct indices', () {
      expect(WorkerMessageType.init.index, equals(0));
      expect(WorkerMessageType.call.index, equals(1));
      expect(WorkerMessageType.result.index, equals(2));
      expect(WorkerMessageType.error.index, equals(3));
      expect(WorkerMessageType.shutdown.index, equals(4));
    });

    test('enum values have correct names', () {
      expect(WorkerMessageType.init.name, equals('init'));
      expect(WorkerMessageType.call.name, equals('call'));
      expect(WorkerMessageType.result.name, equals('result'));
      expect(WorkerMessageType.error.name, equals('error'));
      expect(WorkerMessageType.shutdown.name, equals('shutdown'));
    });
  });

  group('WorkerMessage', () {
    test('creates message with required type only', () {
      final message = WorkerMessage(type: WorkerMessageType.init);

      expect(message.type, equals(WorkerMessageType.init));
      expect(message.id, isNull);
      expect(message.data, isNull);
    });

    test('creates message with all parameters', () {
      final message = WorkerMessage(
        type: WorkerMessageType.call,
        id: 'test-id-123',
        data: {'key': 'value'},
      );

      expect(message.type, equals(WorkerMessageType.call));
      expect(message.id, equals('test-id-123'));
      expect(message.data, isA<Map>());
      expect(message.data['key'], equals('value'));
    });

    test('creates result message with data', () {
      final message = WorkerMessage(
        type: WorkerMessageType.result,
        id: 'result-id',
        data: 42,
      );

      expect(message.type, equals(WorkerMessageType.result));
      expect(message.id, equals('result-id'));
      expect(message.data, equals(42));
    });

    test('creates error message with error data', () {
      final message = WorkerMessage(
        type: WorkerMessageType.error,
        id: 'error-id',
        data: 'Something went wrong',
      );

      expect(message.type, equals(WorkerMessageType.error));
      expect(message.id, equals('error-id'));
      expect(message.data, equals('Something went wrong'));
    });

    test('creates shutdown message', () {
      final message = WorkerMessage(type: WorkerMessageType.shutdown);

      expect(message.type, equals(WorkerMessageType.shutdown));
      expect(message.id, isNull);
      expect(message.data, isNull);
    });

    test('supports various data types', () {
      // String data
      final stringMessage = WorkerMessage(
        type: WorkerMessageType.result,
        id: 'string-id',
        data: 'Hello World',
      );
      expect(stringMessage.data, isA<String>());

      // Integer data
      final intMessage = WorkerMessage(
        type: WorkerMessageType.result,
        id: 'int-id',
        data: 123,
      );
      expect(intMessage.data, isA<int>());

      // Double data
      final doubleMessage = WorkerMessage(
        type: WorkerMessageType.result,
        id: 'double-id',
        data: 3.14159,
      );
      expect(doubleMessage.data, isA<double>());

      // List data
      final listMessage = WorkerMessage(
        type: WorkerMessageType.result,
        id: 'list-id',
        data: [1, 2, 3, 4, 5],
      );
      expect(listMessage.data, isA<List>());
      expect((listMessage.data as List).length, equals(5));

      // Map data
      final mapMessage = WorkerMessage(
        type: WorkerMessageType.result,
        id: 'map-id',
        data: {'nested': {'deep': 'value'}},
      );
      expect(mapMessage.data, isA<Map>());

      // Boolean data
      final boolMessage = WorkerMessage(
        type: WorkerMessageType.result,
        id: 'bool-id',
        data: true,
      );
      expect(boolMessage.data, isA<bool>());
    });

    test('accepts null data explicitly', () {
      final message = WorkerMessage(
        type: WorkerMessageType.result,
        id: 'null-id',
        data: null,
      );

      expect(message.data, isNull);
    });

    test('accepts empty string id', () {
      final message = WorkerMessage(
        type: WorkerMessageType.call,
        id: '',
        data: 'test',
      );

      expect(message.id, equals(''));
    });
  });

  group('IsolateWorker', () {
    group('isRunning state', () {
      test('isRunning is false before start', () {
        final worker = IsolateWorker();
        expect(worker.isRunning, isFalse);
      });

      test('multiple workers can be created independently', () {
        final worker1 = IsolateWorker();
        final worker2 = IsolateWorker();
        final worker3 = IsolateWorker();

        expect(worker1.isRunning, isFalse);
        expect(worker2.isRunning, isFalse);
        expect(worker3.isRunning, isFalse);
      });
    });

    group('execute without start', () {
      test('execute throws StateError when not started', () async {
        final worker = IsolateWorker();

        expect(
          () => worker.execute('test-id', () => 42),
          throwsA(isA<StateError>()),
        );
      });

      test('execute throws StateError with correct message', () async {
        final worker = IsolateWorker();

        expect(
          () => worker.execute('test-id', () => 'result'),
          throwsA(
            predicate<StateError>(
              (e) => e.message == 'Worker not started',
            ),
          ),
        );
      });

      test('execute throws for various work types when not started', () async {
        final worker = IsolateWorker();

        // Simple function
        expect(
          () => worker.execute<int>('id1', () => 1),
          throwsStateError,
        );

        // Function returning string
        expect(
          () => worker.execute<String>('id2', () => 'test'),
          throwsStateError,
        );

        // Function returning list
        expect(
          () => worker.execute<List>('id3', () => [1, 2, 3]),
          throwsStateError,
        );

        // Function returning map
        expect(
          () => worker.execute<Map>('id4', () => {'key': 'value'}),
          throwsStateError,
        );
      });
    });
  });

  group('Message handling simulation', () {
    test('simulates result message handling', () async {
      final pendingRequests = <String, Completer<dynamic>>{};
      final completer = Completer<int>();
      pendingRequests['request-1'] = completer;

      // Simulate receiving a result message
      final resultMessage = WorkerMessage(
        type: WorkerMessageType.result,
        id: 'request-1',
        data: 42,
      );

      // Simulate _handleMessage logic for result
      final requestCompleter = pendingRequests.remove(resultMessage.id);
      if (requestCompleter != null &&
          resultMessage.type == WorkerMessageType.result) {
        requestCompleter.complete(resultMessage.data);
      }

      expect(await completer.future, equals(42));
      expect(pendingRequests.containsKey('request-1'), isFalse);
    });

    test('simulates error message handling', () async {
      final pendingRequests = <String, Completer<dynamic>>{};
      final completer = Completer<int>();
      pendingRequests['request-2'] = completer;

      // Simulate receiving an error message
      final errorMessage = WorkerMessage(
        type: WorkerMessageType.error,
        id: 'request-2',
        data: 'Computation failed',
      );

      // Simulate _handleMessage logic for error
      final requestCompleter = pendingRequests.remove(errorMessage.id);
      if (requestCompleter != null &&
          errorMessage.type == WorkerMessageType.error) {
        requestCompleter.completeError(errorMessage.data);
      }

      expect(
        () => completer.future,
        throwsA(equals('Computation failed')),
      );
    });

    test('ignores messages with unknown ids', () async {
      final pendingRequests = <String, Completer<dynamic>>{};
      final completer = Completer<int>();
      pendingRequests['known-id'] = completer;

      // Simulate receiving a message with unknown id
      final unknownMessage = WorkerMessage(
        type: WorkerMessageType.result,
        id: 'unknown-id',
        data: 100,
      );

      // Simulate _handleMessage logic
      final requestCompleter = pendingRequests.remove(unknownMessage.id);
      if (requestCompleter != null) {
        requestCompleter.complete(unknownMessage.data);
      }

      // Original completer should not be completed
      expect(completer.isCompleted, isFalse);
      // Known request should still be pending
      expect(pendingRequests.containsKey('known-id'), isTrue);
    });

    test('simulates multiple concurrent request tracking', () async {
      final pendingRequests = <String, Completer<dynamic>>{};
      final results = <String, dynamic>{};

      // Add multiple pending requests
      for (var i = 1; i <= 5; i++) {
        final completer = Completer<int>();
        pendingRequests['request-$i'] = completer;
        completer.future.then((value) => results['request-$i'] = value);
      }

      expect(pendingRequests.length, equals(5));

      // Simulate receiving results in random order
      for (final id in ['request-3', 'request-1', 'request-5']) {
        final message = WorkerMessage(
          type: WorkerMessageType.result,
          id: id,
          data: int.parse(id.split('-')[1]) * 10,
        );

        final completer = pendingRequests.remove(message.id);
        completer?.complete(message.data);
      }

      await Future.delayed(Duration.zero);

      expect(results['request-1'], equals(10));
      expect(results['request-3'], equals(30));
      expect(results['request-5'], equals(50));
      expect(results.containsKey('request-2'), isFalse);
      expect(results.containsKey('request-4'), isFalse);
      expect(pendingRequests.length, equals(2));
    });

    test('result matching correctly associates responses by id', () async {
      final pendingRequests = <String, Completer<dynamic>>{};

      // Create requests with different expected types
      final stringCompleter = Completer<String>();
      final intCompleter = Completer<int>();
      final listCompleter = Completer<List>();

      pendingRequests['string-req'] = stringCompleter;
      pendingRequests['int-req'] = intCompleter;
      pendingRequests['list-req'] = listCompleter;

      // Simulate receiving results in different order than created
      final messages = [
        WorkerMessage(
            type: WorkerMessageType.result, id: 'int-req', data: 42),
        WorkerMessage(
            type: WorkerMessageType.result, id: 'list-req', data: [1, 2, 3]),
        WorkerMessage(
            type: WorkerMessageType.result, id: 'string-req', data: 'hello'),
      ];

      for (final msg in messages) {
        final completer = pendingRequests.remove(msg.id);
        if (msg.type == WorkerMessageType.result) {
          completer?.complete(msg.data);
        }
      }

      expect(await stringCompleter.future, equals('hello'));
      expect(await intCompleter.future, equals(42));
      expect(await listCompleter.future, equals([1, 2, 3]));
    });
  });

  group('Worker lifecycle simulation', () {
    test('simulates start sets isRunning state', () {
      Object? isolate;
      bool isRunning() => isolate != null;

      expect(isRunning(), isFalse);

      // Simulate start
      isolate = Object(); // Placeholder for actual Isolate
      expect(isRunning(), isTrue);
    });

    test('simulates stop clears state', () {
      Object? isolate = Object();
      Object? sendPort = Object();
      final pendingRequests = <String, Completer<dynamic>>{};

      // Add some pending requests
      pendingRequests['req-1'] = Completer<int>();
      pendingRequests['req-2'] = Completer<String>();

      bool isRunning() => isolate != null;
      expect(isRunning(), isTrue);

      // Simulate stop
      isolate = null;
      sendPort = null;

      expect(isolate, isNull);
      expect(sendPort, isNull);
    });

    test('simulates start is idempotent', () {
      var startCount = 0;
      Object? isolate;

      void start() {
        if (isolate != null) return;
        isolate = Object();
        startCount++;
      }

      start();
      start();
      start();

      expect(startCount, equals(1));
    });
  });

  group('Concurrent execution simulation', () {
    test('tracks multiple pending requests simultaneously', () {
      final pendingRequests = <String, Completer<dynamic>>{};

      // Simulate multiple execute calls
      final ids = ['exec-1', 'exec-2', 'exec-3', 'exec-4', 'exec-5'];
      final futures = <Future<int>>[];

      for (final id in ids) {
        final completer = Completer<int>();
        pendingRequests[id] = completer;
        futures.add(completer.future);
      }

      expect(pendingRequests.length, equals(5));
      expect(futures.length, equals(5));

      // Verify each id is tracked
      for (final id in ids) {
        expect(pendingRequests.containsKey(id), isTrue);
      }
    });

    test('concurrent completions do not interfere', () async {
      final pendingRequests = <String, Completer<dynamic>>{};
      final results = <String, int>{};

      // Add concurrent requests
      for (var i = 0; i < 10; i++) {
        final completer = Completer<int>();
        pendingRequests['concurrent-$i'] = completer;
        completer.future.then((v) => results['concurrent-$i'] = v);
      }

      // Complete all at once
      final entries = pendingRequests.entries.toList();
      for (var i = 0; i < entries.length; i++) {
        entries[i].value.complete(i * 100);
      }
      pendingRequests.clear();

      await Future.delayed(Duration.zero);

      // Verify all got correct results
      for (var i = 0; i < 10; i++) {
        expect(results['concurrent-$i'], equals(i * 100));
      }
    });

    test('handles mixed success and error responses', () async {
      final pendingRequests = <String, Completer<dynamic>>{};
      final successResults = <String, dynamic>{};
      final errorResults = <String, dynamic>{};

      // Create mixed requests
      for (var i = 0; i < 6; i++) {
        final completer = Completer<dynamic>();
        pendingRequests['mixed-$i'] = completer;
        completer.future.then(
          (v) => successResults['mixed-$i'] = v,
          onError: (e) => errorResults['mixed-$i'] = e,
        );
      }

      // Complete evens with success, odds with error
      for (var i = 0; i < 6; i++) {
        final completer = pendingRequests.remove('mixed-$i')!;
        if (i % 2 == 0) {
          completer.complete('success-$i');
        } else {
          completer.completeError('error-$i');
        }
      }

      await Future.delayed(Duration.zero);

      expect(successResults['mixed-0'], equals('success-0'));
      expect(successResults['mixed-2'], equals('success-2'));
      expect(successResults['mixed-4'], equals('success-4'));
      expect(errorResults['mixed-1'], equals('error-1'));
      expect(errorResults['mixed-3'], equals('error-3'));
      expect(errorResults['mixed-5'], equals('error-5'));
    });
  });

  group('Edge cases', () {
    test('handles empty id string', () async {
      final pendingRequests = <String, Completer<dynamic>>{};
      final completer = Completer<String>();
      pendingRequests[''] = completer;

      final message = WorkerMessage(
        type: WorkerMessageType.result,
        id: '',
        data: 'empty-id-result',
      );

      final requestCompleter = pendingRequests.remove(message.id);
      requestCompleter?.complete(message.data);

      expect(await completer.future, equals('empty-id-result'));
    });

    test('handles null id in message gracefully', () {
      final pendingRequests = <String, Completer<dynamic>>{};
      final completer = Completer<String>();
      pendingRequests['valid-id'] = completer;

      final message = WorkerMessage(
        type: WorkerMessageType.result,
        id: null,
        data: 'null-id-result',
      );

      // This should return null since null key doesn't exist
      final requestCompleter = pendingRequests.remove(message.id);
      expect(requestCompleter, isNull);
      expect(completer.isCompleted, isFalse);
    });

    test('handles very long id strings', () async {
      final pendingRequests = <String, Completer<dynamic>>{};
      final longId = 'x' * 10000;
      final completer = Completer<int>();
      pendingRequests[longId] = completer;

      final message = WorkerMessage(
        type: WorkerMessageType.result,
        id: longId,
        data: 999,
      );

      final requestCompleter = pendingRequests.remove(message.id);
      requestCompleter?.complete(message.data);

      expect(await completer.future, equals(999));
    });

    test('handles special characters in id', () async {
      final pendingRequests = <String, Completer<dynamic>>{};
      final specialIds = [
        'id-with-dashes',
        'id_with_underscores',
        'id.with.dots',
        'id/with/slashes',
        'id:with:colons',
        'id with spaces',
        'id\twith\ttabs',
        'id\nwith\nnewlines',
      ];

      for (final id in specialIds) {
        final completer = Completer<String>();
        pendingRequests[id] = completer;

        final message = WorkerMessage(
          type: WorkerMessageType.result,
          id: id,
          data: 'result-$id',
        );

        final requestCompleter = pendingRequests.remove(message.id);
        requestCompleter?.complete(message.data);

        expect(await completer.future, equals('result-$id'));
      }
    });

    test('handles rapid successive operations', () async {
      final pendingRequests = <String, Completer<dynamic>>{};
      final completedCount = <int>[0];

      // Rapidly add and complete requests
      for (var i = 0; i < 1000; i++) {
        final completer = Completer<int>();
        pendingRequests['rapid-$i'] = completer;
        completer.future.then((_) => completedCount[0]++);
      }

      // Complete all immediately
      for (var i = 0; i < 1000; i++) {
        pendingRequests.remove('rapid-$i')?.complete(i);
      }

      await Future.delayed(const Duration(milliseconds: 10));

      expect(completedCount[0], equals(1000));
      expect(pendingRequests.isEmpty, isTrue);
    });
  });

  group('Message type routing', () {
    test('result messages complete successfully', () async {
      final completer = Completer<dynamic>();
      final message = WorkerMessage(
        type: WorkerMessageType.result,
        id: 'route-test',
        data: 'success',
      );

      if (message.type == WorkerMessageType.result) {
        completer.complete(message.data);
      } else if (message.type == WorkerMessageType.error) {
        completer.completeError(message.data);
      }

      expect(await completer.future, equals('success'));
    });

    test('error messages complete with error', () async {
      final completer = Completer<dynamic>();
      final message = WorkerMessage(
        type: WorkerMessageType.error,
        id: 'route-test',
        data: 'failure reason',
      );

      if (message.type == WorkerMessageType.result) {
        completer.complete(message.data);
      } else if (message.type == WorkerMessageType.error) {
        completer.completeError(message.data);
      }

      expect(
        () => completer.future,
        throwsA(equals('failure reason')),
      );
    });

    test('shutdown messages are handled separately', () {
      var shutdownReceived = false;
      final message = WorkerMessage(type: WorkerMessageType.shutdown);

      if (message.type == WorkerMessageType.shutdown) {
        shutdownReceived = true;
      }

      expect(shutdownReceived, isTrue);
    });

    test('init messages are handled separately', () {
      var initReceived = false;
      final message = WorkerMessage(type: WorkerMessageType.init);

      if (message.type == WorkerMessageType.init) {
        initReceived = true;
      }

      expect(initReceived, isTrue);
    });

    test('call messages contain work function reference', () {
      dynamic capturedWork;
      final workFunction = () => 42;

      final message = WorkerMessage(
        type: WorkerMessageType.call,
        id: 'work-call',
        data: workFunction,
      );

      if (message.type == WorkerMessageType.call) {
        capturedWork = message.data;
      }

      expect(capturedWork, isNotNull);
      expect(capturedWork, equals(workFunction));
    });
  });

  group('Request cleanup', () {
    test('completed requests are removed from pending map', () {
      final pendingRequests = <String, Completer<dynamic>>{};

      pendingRequests['cleanup-1'] = Completer<int>();
      pendingRequests['cleanup-2'] = Completer<int>();
      pendingRequests['cleanup-3'] = Completer<int>();

      expect(pendingRequests.length, equals(3));

      // Simulate completing one request
      pendingRequests.remove('cleanup-2')?.complete(100);

      expect(pendingRequests.length, equals(2));
      expect(pendingRequests.containsKey('cleanup-2'), isFalse);
      expect(pendingRequests.containsKey('cleanup-1'), isTrue);
      expect(pendingRequests.containsKey('cleanup-3'), isTrue);
    });

    test('errored requests are removed from pending map', () async {
      final pendingRequests = <String, Completer<dynamic>>{};

      pendingRequests['error-1'] = Completer<int>();
      pendingRequests['error-2'] = Completer<int>();

      expect(pendingRequests.length, equals(2));

      // Simulate error completion - need to listen to the future to avoid unhandled error
      final completer = pendingRequests.remove('error-1');
      // Ignore the error when completing with error
      completer?.future.catchError((_) => 0);
      completer?.completeError('test error');

      expect(pendingRequests.length, equals(1));
      expect(pendingRequests.containsKey('error-1'), isFalse);
    });

    test('multiple removals of same id are safe', () {
      final pendingRequests = <String, Completer<dynamic>>{};
      pendingRequests['single'] = Completer<int>();

      final first = pendingRequests.remove('single');
      final second = pendingRequests.remove('single');
      final third = pendingRequests.remove('single');

      expect(first, isNotNull);
      expect(second, isNull);
      expect(third, isNull);
    });
  });
}
