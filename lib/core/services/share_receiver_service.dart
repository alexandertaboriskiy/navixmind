import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Receives files shared from other Android apps via the share sheet.
///
/// Listens on the `ai.navixmind/share_receiver` MethodChannel for
/// `onFilesShared` calls from Kotlin, and exposes them as a stream
/// for ChatScreen to consume.
class ShareReceiverService {
  static final instance = ShareReceiverService._();
  ShareReceiverService._();

  @visibleForTesting
  ShareReceiverService.forTest();

  static const _channel = MethodChannel('ai.navixmind/share_receiver');

  final _controller = StreamController<SharedFilesEvent>.broadcast();
  Stream<SharedFilesEvent> get stream => _controller.stream;

  /// Buffer for files received before anyone listens (cold start)
  SharedFilesEvent? _pendingEvent;

  void initialize() {
    _channel.setMethodCallHandler(handleMethodCall);
  }

  /// Handles incoming method calls from the Kotlin share channel.
  /// Exposed as public for testing — use [initialize] for production.
  @visibleForTesting
  Future<dynamic> handleMethodCall(MethodCall call) async {
    if (call.method == 'onFilesShared') {
      try {
        final args = Map<String, dynamic>.from(call.arguments as Map);
        final rawFiles = args['files'] as List?;
        final filesList = rawFiles?.map((f) {
          final map = Map<String, dynamic>.from(f as Map);
          return SharedFileInfo(
            path: map['path'] as String? ?? '',
            name: map['name'] as String? ?? 'unknown',
            size: (map['size'] as num?)?.toInt() ?? 0,
            error: map['error'] as String?,
          );
        }).toList() ?? [];

        final text = args['text'] as String?;
        final event = SharedFilesEvent(files: filesList, text: text);

        if (_controller.hasListener) {
          _controller.add(event);
        } else {
          _pendingEvent = event;
        }
      } catch (e) {
        debugPrint('ShareReceiverService: Error parsing shared files: $e');
      }
    }
  }

  /// Consume any buffered event (call after subscribing to the stream).
  SharedFilesEvent? consumePending() {
    final event = _pendingEvent;
    _pendingEvent = null;
    return event;
  }

  void dispose() {
    _controller.close();
  }
}

class SharedFilesEvent {
  final List<SharedFileInfo> files;
  final String? text;

  SharedFilesEvent({required this.files, this.text});
}

class SharedFileInfo {
  final String path;
  final String name;
  final int size;
  final String? error;

  SharedFileInfo({
    required this.path,
    required this.name,
    required this.size,
    this.error,
  });
}
