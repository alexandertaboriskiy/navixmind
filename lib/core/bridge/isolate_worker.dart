import 'dart:async';
import 'dart:isolate';

/// Message types for isolate communication
enum WorkerMessageType {
  init,
  call,
  result,
  error,
  shutdown,
}

/// Message sent to/from worker isolate
class WorkerMessage {
  final WorkerMessageType type;
  final String? id;
  final dynamic data;

  WorkerMessage({
    required this.type,
    this.id,
    this.data,
  });
}

/// Background isolate worker for heavy Python operations
///
/// This isolate can perform long-running operations without
/// blocking the main UI thread.
///
/// NOTE: In the actual implementation, Python calls go through
/// the platform channel which already runs in a background thread
/// on the Kotlin side. This isolate is reserved for additional
/// Dart-side heavy lifting if needed.
class IsolateWorker {
  Isolate? _isolate;
  SendPort? _sendPort;
  final _receivePort = ReceivePort();
  final _pendingRequests = <String, Completer<dynamic>>{};

  bool get isRunning => _isolate != null;

  /// Start the worker isolate
  Future<void> start() async {
    if (_isolate != null) return;

    _isolate = await Isolate.spawn(
      _workerEntryPoint,
      _receivePort.sendPort,
    );

    _receivePort.listen(_handleMessage);

    // Wait for worker to send its SendPort
    final completer = Completer<SendPort>();
    _pendingRequests['_init'] = completer;
    _sendPort = await completer.future;
  }

  /// Stop the worker isolate
  void stop() {
    _sendPort?.send(WorkerMessage(type: WorkerMessageType.shutdown));
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _sendPort = null;
    _receivePort.close();
  }

  /// Execute a function in the worker isolate
  Future<T> execute<T>(String id, dynamic Function() work) async {
    if (_sendPort == null) {
      throw StateError('Worker not started');
    }

    final completer = Completer<T>();
    _pendingRequests[id] = completer;

    _sendPort!.send(WorkerMessage(
      type: WorkerMessageType.call,
      id: id,
      data: work,
    ));

    return completer.future;
  }

  void _handleMessage(dynamic message) {
    if (message is SendPort) {
      // Initial handshake
      final completer = _pendingRequests.remove('_init');
      completer?.complete(message);
      return;
    }

    if (message is WorkerMessage) {
      final completer = _pendingRequests.remove(message.id);
      if (completer == null) return;

      if (message.type == WorkerMessageType.result) {
        completer.complete(message.data);
      } else if (message.type == WorkerMessageType.error) {
        completer.completeError(message.data);
      }
    }
  }

  static void _workerEntryPoint(SendPort mainSendPort) {
    final workerReceivePort = ReceivePort();
    mainSendPort.send(workerReceivePort.sendPort);

    workerReceivePort.listen((message) {
      if (message is WorkerMessage) {
        if (message.type == WorkerMessageType.shutdown) {
          workerReceivePort.close();
          return;
        }

        if (message.type == WorkerMessageType.call) {
          try {
            final work = message.data as dynamic Function();
            final result = work();
            mainSendPort.send(WorkerMessage(
              type: WorkerMessageType.result,
              id: message.id,
              data: result,
            ));
          } catch (e) {
            mainSendPort.send(WorkerMessage(
              type: WorkerMessageType.error,
              id: message.id,
              data: e.toString(),
            ));
          }
        }
      }
    });
  }
}
