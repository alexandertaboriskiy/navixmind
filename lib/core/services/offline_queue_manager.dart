import 'dart:async';

import 'package:isar/isar.dart';

import '../bridge/bridge.dart';
import '../database/collections/pending_query.dart';
import 'connectivity_service.dart';

/// Manages the offline queue for messages sent while offline.
///
/// Features:
/// - Queues messages when offline
/// - Automatically processes queue when back online
/// - Emits events for UI feedback
/// - Handles retry with exponential backoff
class OfflineQueueManager {
  static OfflineQueueManager? _instance;
  static OfflineQueueManager get instance {
    _instance ??= OfflineQueueManager._();
    return _instance!;
  }

  OfflineQueueManager._();

  late PendingQueryRepository _repository;
  late ConnectivityService _connectivity;
  late PythonBridge _bridge;

  StreamSubscription? _connectivitySubscription;
  final _queueController = StreamController<OfflineQueueEvent>.broadcast();
  bool _isProcessing = false;
  int _pendingCount = 0;

  /// Stream of queue events for UI updates
  Stream<OfflineQueueEvent> get queueStream => _queueController.stream;

  /// Number of pending messages in queue
  int get pendingCount => _pendingCount;

  /// Whether there are messages waiting to be sent
  bool get hasPending => _pendingCount > 0;

  /// Initialize the queue manager
  Future<void> initialize(Isar isar) async {
    _repository = PendingQueryRepository(isar);
    _connectivity = ConnectivityService.instance;
    _bridge = PythonBridge.instance;

    // Update initial count
    _pendingCount = await _repository.getPendingCount();

    // Listen for connectivity changes
    _connectivitySubscription = _connectivity.statusStream.listen((isOnline) {
      if (isOnline) {
        _processQueue();
      }
    });

    // Process any pending items if online
    if (_connectivity.isOnline) {
      _processQueue();
    }
  }

  /// Queue a message for later sending
  ///
  /// Returns the queue ID for tracking
  Future<int> queueMessage({
    required String query,
    List<String>? attachmentPaths,
  }) async {
    final id = await _repository.queue(
      query: query,
      attachmentPaths: attachmentPaths,
    );

    _pendingCount++;
    _queueController.add(OfflineQueueEvent(
      type: OfflineQueueEventType.messageQueued,
      pendingCount: _pendingCount,
      message: 'Message queued for later',
    ));

    return id;
  }

  /// Process all pending messages
  Future<void> _processQueue() async {
    if (_isProcessing) return;
    if (!_connectivity.isOnline) return;

    _isProcessing = true;
    _queueController.add(OfflineQueueEvent(
      type: OfflineQueueEventType.processingStarted,
      pendingCount: _pendingCount,
      message: 'Processing queued messages...',
    ));

    try {
      while (_connectivity.isOnline) {
        final pending = await _repository.getPending();
        if (pending.isEmpty) break;

        for (final query in pending) {
          if (!_connectivity.isOnline) break;

          await _repository.markProcessing(query.id);

          try {
            _queueController.add(OfflineQueueEvent(
              type: OfflineQueueEventType.processingMessage,
              pendingCount: _pendingCount,
              message: 'Sending: ${_truncate(query.query, 30)}...',
            ));

            final response = await _bridge.sendQuery(
              query: query.query,
              filePaths:
                  query.attachmentPaths.isNotEmpty ? query.attachmentPaths : null,
            );

            if (response.isSuccess) {
              await _repository.markCompleted(query.id);
              _pendingCount--;

              _queueController.add(OfflineQueueEvent(
                type: OfflineQueueEventType.messageSent,
                pendingCount: _pendingCount,
                message: 'Message sent successfully',
                result: response.result,
              ));
            } else {
              await _repository.markFailed(
                query.id,
                response.error?.message ?? 'Unknown error',
              );
              _pendingCount--;

              _queueController.add(OfflineQueueEvent(
                type: OfflineQueueEventType.messageFailed,
                pendingCount: _pendingCount,
                message: 'Failed to send message',
                error: response.error?.message,
              ));
            }
          } catch (e) {
            // Connection error - stop processing but keep in queue
            await _repository.markFailed(query.id, e.toString());
            _queueController.add(OfflineQueueEvent(
              type: OfflineQueueEventType.processingPaused,
              pendingCount: _pendingCount,
              message: 'Connection lost, will retry when online',
            ));
            break;
          }
        }

        // Small delay between processing batches
        await Future.delayed(const Duration(milliseconds: 500));
      }
    } finally {
      _isProcessing = false;

      if (_pendingCount == 0) {
        _queueController.add(OfflineQueueEvent(
          type: OfflineQueueEventType.queueEmpty,
          pendingCount: 0,
          message: 'All messages sent',
        ));
      }
    }
  }

  /// Clear failed messages from queue
  Future<void> clearFailed() async {
    await _repository.clearProcessed();
    _pendingCount = await _repository.getPendingCount();
  }

  String _truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _queueController.close();
  }
}

/// Event types for offline queue
enum OfflineQueueEventType {
  messageQueued,
  processingStarted,
  processingMessage,
  messageSent,
  messageFailed,
  processingPaused,
  queueEmpty,
}

/// Event from offline queue
class OfflineQueueEvent {
  final OfflineQueueEventType type;
  final int pendingCount;
  final String message;
  final Map<String, dynamic>? result;
  final String? error;

  OfflineQueueEvent({
    required this.type,
    required this.pendingCount,
    required this.message,
    this.result,
    this.error,
  });
}
