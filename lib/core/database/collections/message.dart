import 'package:isar/isar.dart';

part 'message.g.dart';

/// Message roles
enum MessageRole {
  user,
  assistant,
  system,
  toolResult,
}

/// Attachment types
enum AttachmentType {
  image,
  video,
  pdf,
  audio,
  file,
}

/// Tool call status
enum ToolCallStatus {
  pending,
  running,
  success,
  error,
}

@collection
class Message {
  Id id = Isar.autoIncrement;

  @Index()
  late int conversationId;

  @enumerated
  late MessageRole role;

  late String content;

  late DateTime createdAt;

  /// Estimated token count for context management
  int tokenCount = 0;

  /// Embedded attachments
  List<Attachment> attachments = [];

  /// Embedded tool calls (for assistant messages)
  List<ToolCall> toolCalls = [];

  Message();

  factory Message.create({
    required int conversationId,
    required MessageRole role,
    required String content,
    List<Attachment>? attachments,
    List<ToolCall>? toolCalls,
  }) {
    return Message()
      ..conversationId = conversationId
      ..role = role
      ..content = content
      ..createdAt = DateTime.now()
      ..tokenCount = _estimateTokens(content)
      ..attachments = attachments ?? []
      ..toolCalls = toolCalls ?? [];
  }

  static int _estimateTokens(String text) {
    // Rough estimate: ~4 characters per token
    return (text.length / 4).ceil();
  }

  Map<String, dynamic> toSyncJson() => {
    'id': id,
    'role': role.name,
    'content': content,
    'token_count': tokenCount,
    'attachments': attachments.map((a) => a.toJson()).toList(),
    'tool_calls': toolCalls.map((t) => t.toJson()).toList(),
  };
}

@embedded
class Attachment {
  @enumerated
  AttachmentType type = AttachmentType.file;

  String localPath = '';

  String originalName = '';

  String mimeType = '';

  int sizeBytes = 0;

  /// Additional metadata (e.g., duration for video)
  String? metadataJson;

  Attachment();

  factory Attachment.create({
    required AttachmentType type,
    required String localPath,
    required String originalName,
    required String mimeType,
    required int sizeBytes,
    Map<String, dynamic>? metadata,
  }) {
    return Attachment()
      ..type = type
      ..localPath = localPath
      ..originalName = originalName
      ..mimeType = mimeType
      ..sizeBytes = sizeBytes;
  }

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'local_path': localPath,
    'original_name': originalName,
    'mime_type': mimeType,
    'size_bytes': sizeBytes,
  };
}

@embedded
class ToolCall {
  String toolName = '';

  String inputJson = '';

  String outputJson = '';

  @enumerated
  ToolCallStatus status = ToolCallStatus.pending;

  int durationMs = 0;

  ToolCall();

  factory ToolCall.create({
    required String toolName,
    required String inputJson,
  }) {
    return ToolCall()
      ..toolName = toolName
      ..inputJson = inputJson;
  }

  Map<String, dynamic> toJson() => {
    'tool_name': toolName,
    'input': inputJson,
    'output': outputJson,
    'status': status.name,
    'duration_ms': durationMs,
  };
}
