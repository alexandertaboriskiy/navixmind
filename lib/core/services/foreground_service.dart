import 'package:flutter/services.dart';

/// Client for controlling the Android foreground service from Flutter.
///
/// Used for long-running tasks like video processing that need to
/// survive backgrounding and show progress to the user.
class ForegroundService {
  static const _channel = MethodChannel('ai.navixmind/foreground_service');

  /// Start a foreground service task with a notification.
  ///
  /// [taskId] - Unique identifier for the task
  /// [title] - Title shown in the notification (e.g., "Processing video")
  static Future<void> startTask(String taskId, String title) async {
    try {
      await _channel.invokeMethod('startTask', {
        'taskId': taskId,
        'title': title,
      });
    } on PlatformException catch (e) {
      throw ForegroundServiceException('Failed to start task: ${e.message}');
    }
  }

  /// Update the progress of a running task.
  ///
  /// [taskId] - Task identifier
  /// [progress] - Progress percentage (0-100)
  /// [message] - Message shown in the notification
  static Future<void> updateProgress(
    String taskId,
    int progress,
    String message,
  ) async {
    try {
      await _channel.invokeMethod('updateProgress', {
        'taskId': taskId,
        'progress': progress,
        'message': message,
      });
    } on PlatformException catch (e) {
      throw ForegroundServiceException('Failed to update progress: ${e.message}');
    }
  }

  /// Stop the foreground service.
  static Future<void> stopTask() async {
    try {
      await _channel.invokeMethod('stopTask');
    } on PlatformException catch (e) {
      throw ForegroundServiceException('Failed to stop task: ${e.message}');
    }
  }
}

class ForegroundServiceException implements Exception {
  final String message;
  ForegroundServiceException(this.message);

  @override
  String toString() => 'ForegroundServiceException: $message';
}
