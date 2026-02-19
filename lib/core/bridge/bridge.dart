import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/model_registry.dart';
import '../services/auth_service.dart';
import '../services/cost_manager.dart';
import '../services/storage_service.dart';
import 'messages.dart';

/// Python runtime status
enum PythonStatus {
  uninitialized,
  initializing,
  importing,
  ready,
  error,
  restarting,
}

/// Bridge between Flutter and Python via Chaquopy
///
/// Uses a dedicated isolate for non-blocking communication.
/// All Python calls happen in the background to prevent UI freezes.
class PythonBridge {
  static final PythonBridge instance = PythonBridge._();

  PythonBridge._();

  static const _methodChannel = MethodChannel('ai.navixmind/python_bridge');
  static const _eventChannel = EventChannel('ai.navixmind/python_events');

  final _statusController = StreamController<PythonStatus>.broadcast();
  final _logController = StreamController<LogMessage>.broadcast();
  final _nativeToolController = StreamController<NativeToolRequest>.broadcast();

  StreamSubscription? _eventSubscription;
  PythonStatus _status = PythonStatus.uninitialized;

  /// Stream of Python runtime status changes
  Stream<PythonStatus> get statusStream => _statusController.stream;

  /// Current Python status
  PythonStatus get status => _status;

  /// Stream of log messages from Python
  Stream<LogMessage> get logStream => _logController.stream;

  /// Stream of native tool requests from Python
  Stream<NativeToolRequest> get nativeToolStream => _nativeToolController.stream;

  /// Initialize Python runtime
  Future<void> initialize(String logDir) async {
    if (_status != PythonStatus.uninitialized) return;

    _updateStatus(PythonStatus.initializing);

    // Subscribe to event channel for Python → Flutter messages
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      _handlePythonEvent,
      onError: (error) {
        _logController.add(LogMessage(
          level: 'error',
          message: 'Event channel error: $error',
        ));
      },
    );

    try {
      final result = await _methodChannel.invokeMethod<Map>('initializePython', {
        'logDir': logDir,
      });

      if (result?['success'] == true) {
        _updateStatus(PythonStatus.importing);
        // Python will notify when imports complete via status channel
        await _waitForReady();
      } else {
        _updateStatus(PythonStatus.error);
      }
    } catch (e) {
      _updateStatus(PythonStatus.error);
      rethrow;
    }
  }

  /// Handle incoming event from Python
  void _handlePythonEvent(dynamic event) {
    if (event is! String) return;

    try {
      final json = jsonDecode(event) as Map<String, dynamic>;
      final method = json['method'] as String?;

      if (method == 'log') {
        final params = json['params'] as Map<String, dynamic>;
        _logController.add(LogMessage.fromJson(params));
      } else if (method == 'native_tool') {
        _nativeToolController.add(NativeToolRequest.fromJson(json));
      } else if (method == 'record_usage') {
        // Record API usage for cost tracking
        final params = json['params'] as Map<String, dynamic>;
        CostManager.instance.recordUsage(
          model: params['model'] as String? ?? 'unknown',
          inputTokens: params['input_tokens'] as int? ?? 0,
          outputTokens: params['output_tokens'] as int? ?? 0,
        );
      } else if (method == 'request_fresh_token') {
        // Python is requesting a fresh token (near expiry or 401 received)
        _handleTokenRefreshRequest(json);
      } else if (method == 'auth_error') {
        // Google API returned 401 - token is invalid
        _handleAuthError(json);
      }
    } catch (e) {
      _logController.add(LogMessage(
        level: 'error',
        message: 'Failed to parse Python event: $e',
      ));
    }
  }

  /// Wait for Python to be fully ready
  Future<void> _waitForReady() async {
    // Poll status until ready or error
    for (var i = 0; i < 60; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      try {
        final status = await _methodChannel.invokeMethod<String>('getPythonStatus');
        if (status == 'ready') {
          _updateStatus(PythonStatus.ready);
          return;
        } else if (status == 'error') {
          _updateStatus(PythonStatus.error);
          return;
        }
      } catch (_) {
        // Continue polling
      }
    }
    // Timeout - assume error
    _updateStatus(PythonStatus.error);
  }

  /// Send a query to the Python agent
  ///
  /// If [checkCostLimits] is true (default), will check cost limits before
  /// processing and throw [CostLimitExceededError] if limits are exceeded.
  Future<JsonRpcResponse> sendQuery({
    required String query,
    List<String>? filePaths,
    Map<String, dynamic>? context,
    bool checkCostLimits = true,
  }) async {
    if (_status != PythonStatus.ready) {
      throw StateError('Python is not ready. Status: $_status');
    }

    // Get user's preferred model, tool timeout, and agent limits
    final preferredModel = await CostManager.instance.getPreferredModel();

    // Check if this is an offline model (no cost limits, no API key needed)
    final modelInfo = ModelRegistry.getById(preferredModel);
    final isOfflineModel = modelInfo?.isOffline ?? false;

    // Check cost limits before processing (skip for offline models)
    CostLimitResult? limitResult;
    if (checkCostLimits && !isOfflineModel) {
      limitResult = await CostManager.instance.checkAllLimits();
      if (!limitResult.canProceed) {
        throw CostLimitExceededError(limitResult.message);
      }
    }
    final toolTimeout = await StorageService.instance.getToolTimeout();
    final maxIterations = await StorageService.instance.getMaxIterations();
    final maxToolCalls = await StorageService.instance.getMaxToolCalls();
    final maxTokens = await StorageService.instance.getMaxTokens();

    // Get writable output directory for tools that create files
    // Use external storage so files are visible in file managers
    final extDir = await getExternalStorageDirectory();
    final outputDir = extDir != null
        ? '${extDir.path}/output'
        : '${(await getApplicationDocumentsDirectory()).path}/navixmind_output';

    // Get Google access token if user is signed in
    final googleToken = await AuthService.instance.getValidAccessToken();

    // Get custom system prompt if set
    final customSystemPrompt = await StorageService.instance.getSystemPrompt();

    // Build context with cost information for dynamic model selection
    final enrichedContext = <String, dynamic>{
      ...?context,
      if (limitResult != null) 'cost_percent_used': limitResult.percentUsed,
      if (filePaths != null && filePaths.isNotEmpty) 'has_attachments': true,
      if (preferredModel != 'auto') 'preferred_model': preferredModel,
      'tool_timeout_ms': toolTimeout * 1000,
      'max_iterations': maxIterations,
      'max_tool_calls': maxToolCalls,
      'max_tokens': maxTokens,
      'output_dir': outputDir,
      if (googleToken != null) 'google_access_token': googleToken,
      if (customSystemPrompt != null && !isOfflineModel) 'system_prompt': customSystemPrompt,
      if (isOfflineModel && modelInfo != null) 'offline_model_info': {
        'display_name': modelInfo.displayName,
        'model_lib': modelInfo.mlcModelLib,
      },
    };

    // Copy attached files from cache to persistent storage
    // so they survive cache cleanup and app restarts
    List<String>? persistedPaths;
    if (filePaths != null && filePaths.isNotEmpty) {
      persistedPaths = await _persistAttachedFiles(filePaths);
    }

    final request = JsonRpcRequest(
      method: 'process_query',
      params: {
        'user_query': query,
        if (persistedPaths != null) 'files': persistedPaths,
        'context': enrichedContext,
      },
    );

    return _callPython(request);
  }

  /// Check current cost limit status without sending a query.
  /// Returns the cost limit result with status and message.
  Future<CostLimitResult> checkCostLimits() async {
    return CostManager.instance.checkAllLimits();
  }

  /// Set Claude API key in Python runtime.
  ///
  /// Should be called when user enters API key.
  Future<void> setApiKey(String apiKey) async {
    if (_status != PythonStatus.ready) return;

    final request = JsonRpcRequest(
      method: 'set_api_key',
      params: {'api_key': apiKey},
    );

    await _callPython(request);
  }

  /// Set Mentiora tracing API key in Python runtime.
  ///
  /// Should be called when user configures the key in Settings.
  Future<void> setMentioraApiKey(String apiKey) async {
    if (_status != PythonStatus.ready) return;

    final request = JsonRpcRequest(
      method: 'set_mentiora_key',
      params: {'api_key': apiKey},
    );

    await _callPython(request);
  }

  /// Send fresh access token to Python for Google API calls.
  ///
  /// Should be called:
  /// - After successful sign-in
  /// - When loading a conversation that uses Google tools
  /// - When Python requests a fresh token
  Future<void> sendAccessToken() async {
    if (_status != PythonStatus.ready) return;

    final token = await AuthService.instance.getValidAccessToken();
    if (token == null) return;

    final request = JsonRpcRequest(
      method: 'set_access_token',
      params: {'access_token': token},
    );

    await _callPython(request);
  }

  /// Send conversation to Python for self-improvement of system prompt.
  ///
  /// Uses extended thinking to analyze the conversation and generate
  /// an improved system prompt.
  Future<JsonRpcResponse> selfImprove({
    required List<Map<String, String>> conversationMessages,
    required String currentSystemPrompt,
  }) async {
    if (_status != PythonStatus.ready) {
      throw StateError('Python is not ready. Status: $_status');
    }

    final apiKey = await StorageService.instance.getApiKey();
    if (apiKey == null) {
      throw StateError('API key not configured');
    }

    final request = JsonRpcRequest(
      method: 'self_improve',
      params: {
        'conversation': conversationMessages,
        'current_prompt': currentSystemPrompt,
        'api_key': apiKey,
      },
    );

    return _callPython(request);
  }

  /// Apply a delta update to Python session state
  Future<void> applyDelta(Map<String, dynamic> delta) async {
    if (_status != PythonStatus.ready) {
      throw StateError('Python is not ready. Status: $_status');
    }

    final request = JsonRpcRequest(
      method: 'apply_delta',
      params: delta,
    );

    await _callPython(request);
  }

  /// Send native tool result back to Python
  Future<void> sendToolResult({
    required String id,
    required Map<String, dynamic> result,
  }) async {
    final response = JsonRpcResponse(
      id: id,
      result: result,
    );

    try {
      debugPrint('[Bridge] Sending tool result for id: $id');
      await _methodChannel.invokeMethod('sendResponseToPython', {
        'response': jsonEncode(response.toJson()),
      });
      debugPrint('[Bridge] Tool result sent successfully');
    } catch (e) {
      debugPrint('[Bridge] Failed to send tool result: $e');
      rethrow;
    }
  }

  /// Send native tool error back to Python
  Future<void> sendToolError({
    required String id,
    required int code,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    final response = JsonRpcResponse(
      id: id,
      error: JsonRpcError(code: code, message: message, data: data),
    );

    try {
      debugPrint('[Bridge] Sending tool error for id: $id - $message');
      await _methodChannel.invokeMethod('sendResponseToPython', {
        'response': jsonEncode(response.toJson()),
      });
      debugPrint('[Bridge] Tool error sent successfully');
    } catch (e) {
      debugPrint('[Bridge] Failed to send tool error: $e');
      rethrow;
    }
  }

  /// Handle token refresh request from Python
  Future<void> _handleTokenRefreshRequest(Map<String, dynamic> json) async {
    final requestId = json['id'] as String?;

    try {
      final token = await AuthService.instance.getValidAccessToken();

      if (token != null && requestId != null) {
        await sendToolResult(
          id: requestId,
          result: {'access_token': token},
        );
      } else if (requestId != null) {
        await sendToolError(
          id: requestId,
          code: -32001,
          message: 'Failed to refresh token - user may need to sign in again',
        );
      }
    } catch (e) {
      if (requestId != null) {
        await sendToolError(
          id: requestId,
          code: -32001,
          message: 'Token refresh error: $e',
        );
      }
    }
  }

  /// Handle auth error from Python (Google API returned 401)
  Future<void> _handleAuthError(Map<String, dynamic> json) async {
    final requestId = json['id'] as String?;
    final params = json['params'] as Map<String, dynamic>?;
    final errorMessage = params?['message'] as String? ?? 'Authentication error';

    _logController.add(LogMessage(
      level: 'warning',
      message: 'Auth error from Python: $errorMessage',
    ));

    // Try to get a fresh token automatically
    try {
      final token = await AuthService.instance.getValidAccessToken();

      if (token != null && requestId != null) {
        // Send the new token back so Python can retry
        await sendToolResult(
          id: requestId,
          result: {
            'access_token': token,
            'action': 'retry_with_token',
          },
        );
      } else if (requestId != null) {
        // Token refresh failed - user needs to re-authenticate
        await sendToolError(
          id: requestId,
          code: -32002,
          message: 'Re-authentication required',
          data: {'requires_sign_in': true},
        );
      }
    } catch (e) {
      if (requestId != null) {
        await sendToolError(
          id: requestId,
          code: -32002,
          message: 'Auth recovery failed: $e',
          data: {'requires_sign_in': true},
        );
      }
    }
  }

  /// Copy attached files from cache to persistent internal storage.
  /// Returns the list of persistent paths.
  Future<List<String>> _persistAttachedFiles(List<String> cachePaths) async {
    final appDir = await getApplicationDocumentsDirectory();
    final filesDir = Directory('${appDir.path}/navixmind_files');
    if (!await filesDir.exists()) {
      await filesDir.create(recursive: true);
    }

    final persistedPaths = <String>[];
    for (final cachePath in cachePaths) {
      final file = File(cachePath);
      if (await file.exists()) {
        final filename = p.basename(cachePath);
        final destPath = '${filesDir.path}/$filename';
        final destFile = File(destPath);
        // Only copy if not already there or source is newer
        if (!await destFile.exists()) {
          await file.copy(destPath);
          debugPrint('[Bridge] Persisted file: $filename');
        }
        persistedPaths.add(destPath);
      } else {
        // File doesn't exist in cache, pass original path
        persistedPaths.add(cachePath);
      }
    }
    return persistedPaths;
  }

  Future<JsonRpcResponse> _callPython(JsonRpcRequest request) async {
    try {
      final responseStr = await _methodChannel.invokeMethod<String>(
        'callPython',
        {'payload': jsonEncode(request.toJson())},
      );

      if (responseStr == null) {
        throw Exception('Null response from Python');
      }

      final json = jsonDecode(responseStr) as Map<String, dynamic>;
      return JsonRpcResponse.fromJson(json);
    } on PlatformException catch (e) {
      throw PythonError(e.message ?? 'Unknown Python error', e.details);
    }
  }

  void _updateStatus(PythonStatus newStatus) {
    _status = newStatus;
    _statusController.add(newStatus);
  }

  void dispose() {
    _eventSubscription?.cancel();
    _statusController.close();
    _logController.close();
    _nativeToolController.close();
  }
}

/// Error from Python runtime
class PythonError implements Exception {
  final String message;
  final dynamic details;

  PythonError(this.message, [this.details]);

  @override
  String toString() => 'PythonError: $message';
}

/// Error when cost limits are exceeded
class CostLimitExceededError implements Exception {
  final String message;

  CostLimitExceededError(this.message);

  @override
  String toString() => 'CostLimitExceededError: $message';
}
