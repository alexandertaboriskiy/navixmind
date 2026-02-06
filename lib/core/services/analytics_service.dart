import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Analytics service for tracking user behavior and app usage.
/// All data is anonymous - no personal information is collected.
class AnalyticsService {
  AnalyticsService._();
  static final instance = AnalyticsService._();

  FirebaseAnalytics? _analytics;
  bool _initialized = false;

  /// Initialize the analytics service
  Future<void> initialize() async {
    try {
      _analytics = FirebaseAnalytics.instance;
      _initialized = true;
      debugPrint('Analytics initialized');
    } catch (e) {
      debugPrint('Analytics initialization failed: $e');
    }
  }

  // ============================================
  // SCREEN TRACKING
  // ============================================

  /// Track screen view
  Future<void> screenView(String screenName) async {
    if (!_initialized) return;
    await _analytics?.logScreenView(screenName: screenName);
  }

  // ============================================
  // APP LIFECYCLE
  // ============================================

  /// App opened
  Future<void> appOpen() async {
    if (!_initialized) return;
    await _analytics?.logAppOpen();
  }

  /// First launch ever
  Future<void> firstLaunch() async {
    await _logEvent('first_launch');
  }

  /// Legal terms accepted
  Future<void> legalAccepted() async {
    await _logEvent('legal_accepted');
  }

  /// Legal terms declined
  Future<void> legalDeclined() async {
    await _logEvent('legal_declined');
  }

  // ============================================
  // ONBOARDING & SETUP
  // ============================================

  /// API key entered
  Future<void> apiKeyEntered() async {
    await _logEvent('api_key_entered');
  }

  /// API key validation result
  Future<void> apiKeyValidation({required bool success}) async {
    await _logEvent('api_key_validation', {'success': success});
  }

  /// Google sign in started
  Future<void> googleSignInStarted() async {
    await _logEvent('google_signin_started');
  }

  /// Google sign in completed
  Future<void> googleSignInCompleted({required bool success}) async {
    await _logEvent('google_signin_completed', {'success': success});
  }

  /// Google sign out
  Future<void> googleSignOut() async {
    await _logEvent('google_signout');
  }

  // ============================================
  // CONVERSATIONS
  // ============================================

  /// New conversation created
  Future<void> conversationCreated() async {
    await _logEvent('conversation_created');
  }

  /// Conversation opened
  Future<void> conversationOpened() async {
    await _logEvent('conversation_opened');
  }

  /// Conversation deleted
  Future<void> conversationDeleted() async {
    await _logEvent('conversation_deleted');
  }

  /// All conversations cleared
  Future<void> conversationsCleared() async {
    await _logEvent('conversations_cleared');
  }

  // ============================================
  // MESSAGES & QUERIES
  // ============================================

  /// Message sent
  Future<void> messageSent({
    bool hasAttachments = false,
    int attachmentCount = 0,
    List<String>? attachmentTypes,
  }) async {
    await _logEvent('message_sent', {
      'has_attachments': hasAttachments,
      'attachment_count': attachmentCount,
      if (attachmentTypes != null) 'attachment_types': attachmentTypes.join(','),
    });
  }

  /// Response received
  Future<void> responseReceived({
    required int durationMs,
    required int inputTokens,
    required int outputTokens,
  }) async {
    await _logEvent('response_received', {
      'duration_ms': durationMs,
      'input_tokens': inputTokens,
      'output_tokens': outputTokens,
    });
  }

  /// Query failed
  Future<void> queryFailed({required String error}) async {
    await _logEvent('query_failed', {
      'error': error.length > 100 ? error.substring(0, 100) : error,
    });
  }

  // ============================================
  // TOOL USAGE
  // ============================================

  /// Tool executed
  Future<void> toolExecuted({
    required String toolName,
    required bool success,
    int? durationMs,
  }) async {
    await _logEvent('tool_executed', {
      'tool_name': toolName,
      'success': success,
      if (durationMs != null) 'duration_ms': durationMs,
    });
  }

  /// FFmpeg operation
  Future<void> ffmpegOperation({
    required String operation,
    required bool success,
    int? durationMs,
  }) async {
    await _logEvent('ffmpeg_operation', {
      'operation': operation,
      'success': success,
      if (durationMs != null) 'duration_ms': durationMs,
    });
  }

  /// OCR performed
  Future<void> ocrPerformed({required bool success, int? textLength}) async {
    await _logEvent('ocr_performed', {
      'success': success,
      if (textLength != null) 'text_length': textLength,
    });
  }

  /// PDF operation
  Future<void> pdfOperation({
    required String operation,
    required bool success,
    int? pageCount,
  }) async {
    await _logEvent('pdf_operation', {
      'operation': operation,
      'success': success,
      if (pageCount != null) 'page_count': pageCount,
    });
  }

  /// Web fetch
  Future<void> webFetch({required bool success, String? domain}) async {
    await _logEvent('web_fetch', {
      'success': success,
      if (domain != null) 'domain': domain,
    });
  }

  /// Media download
  Future<void> mediaDownload({
    required String platform,
    required bool success,
  }) async {
    await _logEvent('media_download', {
      'platform': platform,
      'success': success,
    });
  }

  /// Google API call
  Future<void> googleApiCall({
    required String api,
    required String action,
    required bool success,
  }) async {
    await _logEvent('google_api_call', {
      'api': api,
      'action': action,
      'success': success,
    });
  }

  /// Python code executed
  Future<void> pythonCodeExecuted({required bool success}) async {
    await _logEvent('python_code_executed', {'success': success});
  }

  // ============================================
  // FILE OPERATIONS
  // ============================================

  /// File attached
  Future<void> fileAttached({required String fileType, int? sizeBytes}) async {
    await _logEvent('file_attached', {
      'file_type': fileType,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
    });
  }

  /// File shared
  Future<void> fileShared({required String fileType}) async {
    await _logEvent('file_shared', {'file_type': fileType});
  }

  /// File opened
  Future<void> fileOpened({required String fileType}) async {
    await _logEvent('file_opened', {'file_type': fileType});
  }

  // ============================================
  // SETTINGS
  // ============================================

  /// Settings opened
  Future<void> settingsOpened() async {
    await _logEvent('settings_opened');
  }

  /// Setting changed
  Future<void> settingChanged({required String setting, required String value}) async {
    await _logEvent('setting_changed', {
      'setting': setting,
      'value': value,
    });
  }

  /// Theme changed
  Future<void> themeChanged({required String theme}) async {
    await _logEvent('theme_changed', {'theme': theme});
  }

  /// Model changed
  Future<void> modelChanged({required String model}) async {
    await _logEvent('model_changed', {'model': model});
  }

  /// Timeout changed
  Future<void> timeoutChanged({required int seconds}) async {
    await _logEvent('timeout_changed', {'seconds': seconds});
  }

  /// Cost limit changed
  Future<void> costLimitChanged({required double limit}) async {
    await _logEvent('cost_limit_changed', {'limit': limit});
  }

  // ============================================
  // ERRORS & ISSUES
  // ============================================

  /// Error occurred
  Future<void> errorOccurred({
    required String errorType,
    String? message,
  }) async {
    await _logEvent('error_occurred', {
      'error_type': errorType,
      if (message != null) 'message': message.length > 100 ? message.substring(0, 100) : message,
    });
  }

  /// Permission requested
  Future<void> permissionRequested({required String permission}) async {
    await _logEvent('permission_requested', {'permission': permission});
  }

  /// Permission result
  Future<void> permissionResult({
    required String permission,
    required bool granted,
  }) async {
    await _logEvent('permission_result', {
      'permission': permission,
      'granted': granted,
    });
  }

  /// Rate limit hit
  Future<void> rateLimitHit() async {
    await _logEvent('rate_limit_hit');
  }

  /// Cost limit hit
  Future<void> costLimitHit() async {
    await _logEvent('cost_limit_hit');
  }

  // ============================================
  // USAGE METRICS
  // ============================================

  /// Session duration (call on app pause/close)
  Future<void> sessionDuration({required int seconds}) async {
    await _logEvent('session_duration', {'seconds': seconds});
  }

  /// Daily active (call once per day)
  Future<void> dailyActive() async {
    await _logEvent('daily_active');
  }

  /// Set user property
  Future<void> setUserProperty({
    required String name,
    required String? value,
  }) async {
    if (!_initialized) return;
    await _analytics?.setUserProperty(name: name, value: value);
  }

  // ============================================
  // INTERNAL
  // ============================================

  Future<void> _logEvent(String name, [Map<String, dynamic>? params]) async {
    if (!_initialized) return;
    try {
      await _analytics?.logEvent(
        name: name,
        parameters: params?.map((k, v) => MapEntry(k, v?.toString())),
      );
    } catch (e) {
      debugPrint('Analytics event failed: $name - $e');
    }
  }
}
