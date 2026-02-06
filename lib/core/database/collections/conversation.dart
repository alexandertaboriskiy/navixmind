import 'package:isar/isar.dart';

part 'conversation.g.dart';

@collection
class Conversation {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String uuid;

  late String title;

  late DateTime createdAt;

  late DateTime updatedAt;

  bool isArchived = false;

  /// Summary of old messages (for context management)
  String? summary;

  /// ID of last message included in summary
  int? summarizedUpToId;

  Conversation();

  factory Conversation.create({
    required String uuid,
    String title = 'New Conversation',
  }) {
    return Conversation()
      ..uuid = uuid
      ..title = title
      ..createdAt = DateTime.now()
      ..updatedAt = DateTime.now();
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'uuid': uuid,
    'title': title,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'isArchived': isArchived,
    'summary': summary,
  };
}
