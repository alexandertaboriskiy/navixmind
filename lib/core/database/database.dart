import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'collections/conversation.dart';
import 'collections/message.dart';
import 'collections/setting.dart';
import 'collections/api_usage.dart';
import 'collections/pending_query.dart';

/// Database service using Isar
class NavixDatabase {
  static Isar? _instance;

  static Isar get instance {
    if (_instance == null) {
      throw StateError('Database not initialized. Call initialize() first.');
    }
    return _instance!;
  }

  /// Initialize the database
  static Future<Isar> initialize() async {
    if (_instance != null) return _instance!;

    final dir = await getApplicationDocumentsDirectory();

    _instance = await Isar.open(
      [
        ConversationSchema,
        MessageSchema,
        SettingSchema,
        ApiUsageSchema,
        PendingQuerySchema,
      ],
      directory: dir.path,
      name: 'navixmind',
    );

    return _instance!;
  }

  /// Close the database
  static Future<void> close() async {
    await _instance?.close();
    _instance = null;
  }
}
