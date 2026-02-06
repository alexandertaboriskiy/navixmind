import 'dart:io';
import 'dart:math';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Detects and reports Python crashes from log files
class CrashDetector {
  static const _crashLogPath = 'python_crash.log';

  /// Initialize Crashlytics and set up global error handlers
  static Future<void> initialize() async {
    // Set up Flutter error handling
    FlutterError.onError = (errorDetails) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
    };

    // Pass all uncaught asynchronous errors that aren't handled by Flutter
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };

    // Set user identifier if available
    // FirebaseCrashlytics.instance.setUserIdentifier(userId);
  }

  /// Check for previous Python crash on app startup
  static Future<String?> checkForPreviousCrash() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final logFile = File('${dir.path}/$_crashLogPath');

      if (!await logFile.exists()) return null;

      final content = await logFile.readAsString();
      final lastCrash = _extractLastCrash(content);

      if (lastCrash != null) {
        // Clear the processed crash
        await logFile.writeAsString('');
        return lastCrash;
      }

      return null;
    } catch (e) {
      // Silently fail - crash detection is non-critical
      return null;
    }
  }

  /// Extract the last crash from log content
  static String? _extractLastCrash(String content) {
    // Find last "UNCAUGHT EXCEPTION" block
    final pattern = RegExp(
      r'={60}\nUNCAUGHT EXCEPTION.*?(?=={60}|$)',
      dotAll: true,
    );
    final matches = pattern.allMatches(content);

    if (matches.isNotEmpty) {
      return matches.last.group(0);
    }
    return null;
  }

  /// Report crash to Firebase Crashlytics
  static Future<void> reportCrash(String crashLog) async {
    try {
      // Record the Python crash as a non-fatal error
      await FirebaseCrashlytics.instance.recordError(
        PythonCrashException(crashLog),
        StackTrace.current,
        reason: 'Python crash detected on app startup',
        fatal: false,
      );

      // Also log the crash details as custom keys
      await FirebaseCrashlytics.instance.setCustomKey(
        'python_crash_log',
        crashLog.substring(0, min(1000, crashLog.length)),
      );
    } catch (e) {
      // Fallback to console logging if Crashlytics fails
      debugPrint('Failed to report crash to Crashlytics: $e');
      debugPrint('Crash log: ${crashLog.substring(0, min(500, crashLog.length))}');
    }
  }

  /// Log a non-fatal error
  static Future<void> logError(
    dynamic error,
    StackTrace? stackTrace, {
    String? reason,
  }) async {
    await FirebaseCrashlytics.instance.recordError(
      error,
      stackTrace,
      reason: reason,
      fatal: false,
    );
  }

  /// Log a custom message
  static Future<void> log(String message) async {
    await FirebaseCrashlytics.instance.log(message);
  }

  /// Set a custom key-value pair for crash context
  static Future<void> setCustomKey(String key, Object value) async {
    await FirebaseCrashlytics.instance.setCustomKey(key, value);
  }
}

/// Custom exception for Python crashes
class PythonCrashException implements Exception {
  final String crashLog;

  PythonCrashException(this.crashLog);

  @override
  String toString() {
    final firstLine = crashLog.split('\n').firstWhere(
          (line) => line.trim().isNotEmpty && !line.startsWith('='),
          orElse: () => 'Unknown Python crash',
        );
    return 'PythonCrashException: $firstLine';
  }
}
