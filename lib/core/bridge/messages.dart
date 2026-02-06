import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// JSON-RPC 2.0 request message
class JsonRpcRequest {
  final String jsonrpc;
  final String id;
  final String method;
  final Map<String, dynamic> params;

  JsonRpcRequest({
    required this.method,
    required this.params,
    String? id,
  })  : jsonrpc = '2.0',
        id = id ?? _uuid.v4();

  Map<String, dynamic> toJson() => {
    'jsonrpc': jsonrpc,
    'id': id,
    'method': method,
    'params': params,
  };

  factory JsonRpcRequest.fromJson(Map<String, dynamic> json) {
    return JsonRpcRequest(
      id: json['id'] as String,
      method: json['method'] as String,
      params: json['params'] as Map<String, dynamic>? ?? {},
    );
  }
}

/// JSON-RPC 2.0 response message
class JsonRpcResponse {
  final String jsonrpc;
  final String? id;
  final Map<String, dynamic>? result;
  final JsonRpcError? error;

  JsonRpcResponse({
    this.id,
    this.result,
    this.error,
  }) : jsonrpc = '2.0';

  bool get isSuccess => error == null;
  bool get isError => error != null;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'jsonrpc': jsonrpc,
    };
    if (id != null) json['id'] = id;
    if (result != null) json['result'] = result;
    if (error != null) json['error'] = error!.toJson();
    return json;
  }

  factory JsonRpcResponse.fromJson(Map<String, dynamic> json) {
    return JsonRpcResponse(
      id: json['id'] as String?,
      result: json['result'] as Map<String, dynamic>?,
      error: json['error'] != null
          ? JsonRpcError.fromJson(json['error'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// JSON-RPC 2.0 error object
class JsonRpcError {
  final int code;
  final String message;
  final Map<String, dynamic>? data;

  JsonRpcError({
    required this.code,
    required this.message,
    this.data,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'code': code,
      'message': message,
    };
    if (data != null) json['data'] = data;
    return json;
  }

  factory JsonRpcError.fromJson(Map<String, dynamic> json) {
    return JsonRpcError(
      code: json['code'] as int,
      message: json['message'] as String,
      data: json['data'] as Map<String, dynamic>?,
    );
  }

  // Standard JSON-RPC error codes
  static const int parseError = -32700;
  static const int invalidRequest = -32600;
  static const int methodNotFound = -32601;
  static const int invalidParams = -32602;
  static const int internalError = -32603;

  // Custom error codes
  static const int toolError = -32000;
  static const int timeoutError = -32001;
  static const int authError = -32002;
  static const int rateLimitError = -32003;
  static const int fileTooLargeError = -32004;
  static const int policyError = -32005;
}

/// Log message from Python
class LogMessage {
  final String level;
  final String message;
  final double? progress;
  final DateTime timestamp;

  LogMessage({
    required this.level,
    required this.message,
    this.progress,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory LogMessage.fromJson(Map<String, dynamic> json) {
    return LogMessage(
      level: json['level'] as String? ?? 'info',
      message: json['message'] as String,
      progress: (json['progress'] as num?)?.toDouble(),
    );
  }

  bool get isError => level == 'error';
  bool get isWarning => level == 'warn' || level == 'warning';
  bool get hasProgress => progress != null;
}

/// Native tool request from Python
class NativeToolRequest {
  final String id;
  final String tool;
  final Map<String, dynamic> args;
  final int timeoutMs;

  NativeToolRequest({
    required this.id,
    required this.tool,
    required this.args,
    this.timeoutMs = 30000,
  });

  factory NativeToolRequest.fromJson(Map<String, dynamic> json) {
    final params = json['params'] as Map<String, dynamic>;
    return NativeToolRequest(
      id: json['id'] as String,
      tool: params['tool'] as String,
      args: params['args'] as Map<String, dynamic>? ?? {},
      timeoutMs: params['timeout_ms'] as int? ?? 30000,
    );
  }
}

/// Delta sync actions for session state
enum DeltaAction {
  newConversation,
  addMessage,
  setSummary,
  syncFull,
}

/// Delta update for Python session state
class SessionDelta {
  final DeltaAction action;
  final int? conversationId;
  final Map<String, dynamic>? message;
  final List<Map<String, dynamic>>? messages;
  final String? summary;
  final int? summarizedUpToId;

  SessionDelta._({
    required this.action,
    this.conversationId,
    this.message,
    this.messages,
    this.summary,
    this.summarizedUpToId,
  });

  factory SessionDelta.newConversation(int conversationId) {
    return SessionDelta._(
      action: DeltaAction.newConversation,
      conversationId: conversationId,
    );
  }

  factory SessionDelta.addMessage(Map<String, dynamic> message) {
    return SessionDelta._(
      action: DeltaAction.addMessage,
      message: message,
    );
  }

  factory SessionDelta.setSummary({
    required String summary,
    required int summarizedUpToId,
  }) {
    return SessionDelta._(
      action: DeltaAction.setSummary,
      summary: summary,
      summarizedUpToId: summarizedUpToId,
    );
  }

  factory SessionDelta.syncFull({
    required int conversationId,
    required List<Map<String, dynamic>> messages,
    String? summary,
  }) {
    return SessionDelta._(
      action: DeltaAction.syncFull,
      conversationId: conversationId,
      messages: messages,
      summary: summary,
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'action': action.name,
    };

    if (conversationId != null) json['conversation_id'] = conversationId;
    if (message != null) json['message'] = message;
    if (messages != null) json['messages'] = messages;
    if (summary != null) json['summary'] = summary;
    if (summarizedUpToId != null) json['summarized_up_to_id'] = summarizedUpToId;

    return json;
  }
}
