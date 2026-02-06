import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:navixmind/core/database/collections/conversation.dart';
import 'package:navixmind/core/database/collections/message.dart';
import 'package:navixmind/core/database/collections/setting.dart';
import 'package:navixmind/core/database/collections/api_usage.dart';
import 'package:navixmind/core/database/collections/pending_query.dart';

void main() {
  late Isar isar;
  late Directory tempDir;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('isar_test_');
    isar = await Isar.open(
      [
        ConversationSchema,
        MessageSchema,
        SettingSchema,
        ApiUsageSchema,
        PendingQuerySchema,
      ],
      directory: tempDir.path,
      name: 'test_${DateTime.now().millisecondsSinceEpoch}',
    );
  });

  tearDown(() async {
    await isar.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Conversation CRUD operations', () {
    test('creates conversation', () async {
      final conversation = Conversation()
        ..uuid = 'conv-123'
        ..title = 'Test Conversation'
        ..createdAt = DateTime.now()
        ..updatedAt = DateTime.now();

      await isar.writeTxn(() async {
        await isar.conversations.put(conversation);
      });

      expect(conversation.id, isPositive);
    });

    test('reads conversation by id', () async {
      final conversation = Conversation()
        ..uuid = 'conv-456'
        ..title = 'Read Test'
        ..createdAt = DateTime.now()
        ..updatedAt = DateTime.now();

      await isar.writeTxn(() async {
        await isar.conversations.put(conversation);
      });

      final found = await isar.conversations.get(conversation.id);
      expect(found, isNotNull);
      expect(found!.uuid, equals('conv-456'));
      expect(found.title, equals('Read Test'));
    });

    test('updates conversation', () async {
      final conversation = Conversation()
        ..uuid = 'conv-789'
        ..title = 'Original Title'
        ..createdAt = DateTime.now()
        ..updatedAt = DateTime.now();

      await isar.writeTxn(() async {
        await isar.conversations.put(conversation);
      });

      conversation.title = 'Updated Title';
      conversation.updatedAt = DateTime.now();

      await isar.writeTxn(() async {
        await isar.conversations.put(conversation);
      });

      final updated = await isar.conversations.get(conversation.id);
      expect(updated!.title, equals('Updated Title'));
    });

    test('deletes conversation', () async {
      final conversation = Conversation()
        ..uuid = 'conv-to-delete'
        ..title = 'Delete Me'
        ..createdAt = DateTime.now()
        ..updatedAt = DateTime.now();

      await isar.writeTxn(() async {
        await isar.conversations.put(conversation);
      });

      final id = conversation.id;

      await isar.writeTxn(() async {
        await isar.conversations.delete(id);
      });

      final deleted = await isar.conversations.get(id);
      expect(deleted, isNull);
    });

    test('lists all conversations', () async {
      await isar.writeTxn(() async {
        for (var i = 0; i < 5; i++) {
          await isar.conversations.put(Conversation()
            ..uuid = 'conv-list-$i'
            ..title = 'Conversation $i'
            ..createdAt = DateTime.now()
            ..updatedAt = DateTime.now());
        }
      });

      final all = await isar.conversations.where().findAll();
      expect(all.length, equals(5));
    });
  });

  group('Message CRUD operations', () {
    test('creates message', () async {
      final message = Message()
        ..conversationId = 1
        ..role = MessageRole.user
        ..content = 'Hello, world!'
        ..tokenCount = 5
        ..createdAt = DateTime.now();

      await isar.writeTxn(() async {
        await isar.messages.put(message);
      });

      expect(message.id, isPositive);
    });

    test('reads messages by conversation id', () async {
      final conversationId = 100;

      await isar.writeTxn(() async {
        for (var i = 0; i < 3; i++) {
          await isar.messages.put(Message()
            ..conversationId = conversationId
            ..role = i.isEven ? MessageRole.user : MessageRole.assistant
            ..content = 'Message $i'
            ..tokenCount = 5 + i
            ..createdAt = DateTime.now());
        }
      });

      final messages = await isar.messages
          .filter()
          .conversationIdEqualTo(conversationId)
          .findAll();

      expect(messages.length, equals(3));
    });

    test('orders messages by creation time', () async {
      final conversationId = 200;
      final baseTime = DateTime.now();

      await isar.writeTxn(() async {
        for (var i = 0; i < 3; i++) {
          await isar.messages.put(Message()
            ..conversationId = conversationId
            ..role = MessageRole.user
            ..content = 'Message $i'
            ..tokenCount = 5
            ..createdAt = baseTime.add(Duration(seconds: i)));
        }
      });

      final messages = await isar.messages
          .filter()
          .conversationIdEqualTo(conversationId)
          .sortByCreatedAt()
          .findAll();

      expect(messages[0].content, equals('Message 0'));
      expect(messages[2].content, equals('Message 2'));
    });

    test('counts messages in conversation', () async {
      final conversationId = 300;

      await isar.writeTxn(() async {
        for (var i = 0; i < 10; i++) {
          await isar.messages.put(Message()
            ..conversationId = conversationId
            ..role = MessageRole.user
            ..content = 'Message $i'
            ..tokenCount = 5
            ..createdAt = DateTime.now());
        }
      });

      final count = await isar.messages
          .filter()
          .conversationIdEqualTo(conversationId)
          .count();

      expect(count, equals(10));
    });
  });

  group('Setting persistence', () {
    test('saves string setting', () async {
      final setting = Setting()
        ..key = 'api_key'
        ..value = 'sk-test-12345';

      await isar.writeTxn(() async {
        await isar.settings.put(setting);
      });

      final found = await isar.settings
          .filter()
          .keyEqualTo('api_key')
          .findFirst();

      expect(found, isNotNull);
      expect(found!.value, equals('sk-test-12345'));
    });

    test('updates existing setting', () async {
      // Create initial setting
      final setting = Setting()
        ..key = 'theme'
        ..value = 'light';

      await isar.writeTxn(() async {
        await isar.settings.put(setting);
      });

      // Update it
      setting.value = 'dark';

      await isar.writeTxn(() async {
        await isar.settings.put(setting);
      });

      final found = await isar.settings
          .filter()
          .keyEqualTo('theme')
          .findFirst();

      expect(found!.value, equals('dark'));
    });

    test('retrieves multiple settings', () async {
      await isar.writeTxn(() async {
        await isar.settings.put(Setting()
          ..key = 'setting1'
          ..value = 'value1');
        await isar.settings.put(Setting()
          ..key = 'setting2'
          ..value = 'value2');
        await isar.settings.put(Setting()
          ..key = 'setting3'
          ..value = 'value3');
      });

      final all = await isar.settings.where().findAll();
      expect(all.length, equals(3));
    });

    test('deletes setting', () async {
      final setting = Setting()
        ..key = 'temp_setting'
        ..value = 'temp_value';

      await isar.writeTxn(() async {
        await isar.settings.put(setting);
      });

      await isar.writeTxn(() async {
        await isar.settings.delete(setting.id);
      });

      final found = await isar.settings
          .filter()
          .keyEqualTo('temp_setting')
          .findFirst();

      expect(found, isNull);
    });
  });

  group('ApiUsage tracking', () {
    test('records API usage', () async {
      final now = DateTime.now();
      final usage = ApiUsage()
        ..model = 'claude-sonnet-4-20250514'
        ..inputTokens = 1000
        ..outputTokens = 500
        ..date = DateTime(now.year, now.month, now.day)
        ..estimatedCostUsd = 0.018;

      await isar.writeTxn(() async {
        await isar.apiUsages.put(usage);
      });

      expect(usage.id, isPositive);
    });

    test('calculates total cost for period', () async {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);

      await isar.writeTxn(() async {
        for (var i = 0; i < 5; i++) {
          await isar.apiUsages.put(ApiUsage()
            ..model = 'claude-sonnet-4-20250514'
            ..inputTokens = 100
            ..outputTokens = 50
            ..date = todayStart
            ..estimatedCostUsd = 0.01);
        }
      });

      final todayUsage = await isar.apiUsages
          .filter()
          .dateEqualTo(todayStart)
          .findAll();

      final totalCost = todayUsage.fold<double>(0, (sum, u) => sum + u.estimatedCostUsd);
      expect(totalCost, closeTo(0.05, 0.001));
    });

    test('tracks usage by model', () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      await isar.writeTxn(() async {
        await isar.apiUsages.put(ApiUsage()
          ..model = 'claude-3-opus'
          ..inputTokens = 100
          ..outputTokens = 50
          ..date = today
          ..estimatedCostUsd = 0.05);

        await isar.apiUsages.put(ApiUsage()
          ..model = 'claude-3-sonnet'
          ..inputTokens = 100
          ..outputTokens = 50
          ..date = today
          ..estimatedCostUsd = 0.01);

        await isar.apiUsages.put(ApiUsage()
          ..model = 'claude-3-haiku'
          ..inputTokens = 100
          ..outputTokens = 50
          ..date = today
          ..estimatedCostUsd = 0.001);
      });

      final opusUsage = await isar.apiUsages
          .filter()
          .modelEqualTo('claude-3-opus')
          .findAll();

      expect(opusUsage.length, equals(1));
      expect(opusUsage.first.estimatedCostUsd, equals(0.05));
    });
  });

  group('PendingQuery offline queue', () {
    test('queues message for offline sending', () async {
      final pending = PendingQuery.create(
        query: 'Hello, can you help me?',
      );

      await isar.writeTxn(() async {
        await isar.pendingQuerys.put(pending);
      });

      expect(pending.id, isPositive);
    });

    test('queues message with attachments', () async {
      final pending = PendingQuery.create(
        query: 'Check this file',
        attachmentPaths: ['/storage/file1.pdf', '/storage/file2.jpg'],
      );

      await isar.writeTxn(() async {
        await isar.pendingQuerys.put(pending);
      });

      final found = await isar.pendingQuerys.get(pending.id);
      expect(found!.attachmentPaths, isNotNull);
      expect(found.attachmentPaths.length, equals(2));
    });

    test('retrieves pending queries in order', () async {
      final baseTime = DateTime.now();

      await isar.writeTxn(() async {
        for (var i = 0; i < 3; i++) {
          final pending = PendingQuery()
            ..query = 'Message $i'
            ..attachmentPaths = []
            ..createdAt = baseTime.add(Duration(seconds: i));
          await isar.pendingQuerys.put(pending);
        }
      });

      final pending = await isar.pendingQuerys
          .where()
          .sortByCreatedAt()
          .findAll();

      expect(pending.length, equals(3));
      expect(pending.first.query, equals('Message 0'));
    });

    test('removes processed query', () async {
      final pending = PendingQuery.create(
        query: 'Process me',
      );

      await isar.writeTxn(() async {
        await isar.pendingQuerys.put(pending);
      });

      final id = pending.id;

      // Simulate processing
      await isar.writeTxn(() async {
        await isar.pendingQuerys.delete(id);
      });

      final found = await isar.pendingQuerys.get(id);
      expect(found, isNull);
    });

    test('counts pending queries', () async {
      await isar.writeTxn(() async {
        for (var i = 0; i < 5; i++) {
          final pending = PendingQuery.create(
            query: 'Pending $i',
          );
          await isar.pendingQuerys.put(pending);
        }
      });

      final count = await isar.pendingQuerys.count();
      expect(count, equals(5));
    });
  });

  group('Cross-collection operations', () {
    test('creates conversation with messages', () async {
      // Create conversation
      final conversation = Conversation()
        ..uuid = 'full-conv'
        ..title = 'Full Conversation'
        ..createdAt = DateTime.now()
        ..updatedAt = DateTime.now();

      await isar.writeTxn(() async {
        await isar.conversations.put(conversation);
      });

      // Add messages
      await isar.writeTxn(() async {
        await isar.messages.put(Message()
          ..conversationId = conversation.id
          ..role = MessageRole.user
          ..content = 'Hello'
          ..tokenCount = 2
          ..createdAt = DateTime.now());

        await isar.messages.put(Message()
          ..conversationId = conversation.id
          ..role = MessageRole.assistant
          ..content = 'Hi there!'
          ..tokenCount = 3
          ..createdAt = DateTime.now());
      });

      // Verify
      final messages = await isar.messages
          .filter()
          .conversationIdEqualTo(conversation.id)
          .findAll();

      expect(messages.length, equals(2));
    });

    test('deletes conversation and its messages', () async {
      // Create conversation with messages
      final conversation = Conversation()
        ..uuid = 'to-delete'
        ..title = 'Delete Test'
        ..createdAt = DateTime.now()
        ..updatedAt = DateTime.now();

      await isar.writeTxn(() async {
        await isar.conversations.put(conversation);
      });

      await isar.writeTxn(() async {
        for (var i = 0; i < 5; i++) {
          await isar.messages.put(Message()
            ..conversationId = conversation.id
            ..role = MessageRole.user
            ..content = 'Message $i'
            ..tokenCount = 5
            ..createdAt = DateTime.now());
        }
      });

      // Delete conversation and messages
      await isar.writeTxn(() async {
        await isar.messages
            .filter()
            .conversationIdEqualTo(conversation.id)
            .deleteAll();
        await isar.conversations.delete(conversation.id);
      });

      // Verify
      final remainingMessages = await isar.messages
          .filter()
          .conversationIdEqualTo(conversation.id)
          .findAll();

      expect(remainingMessages, isEmpty);
    });
  });

  group('Concurrent access', () {
    test('handles concurrent writes', () async {
      final futures = <Future>[];

      for (var i = 0; i < 10; i++) {
        futures.add(isar.writeTxn(() async {
          await isar.settings.put(Setting()
            ..key = 'concurrent_$i'
            ..value = 'value_$i');
        }));
      }

      await Future.wait(futures);

      final count = await isar.settings.count();
      expect(count, equals(10));
    });

    test('handles concurrent reads', () async {
      // Setup data
      await isar.writeTxn(() async {
        for (var i = 0; i < 100; i++) {
          await isar.messages.put(Message()
            ..conversationId = 1
            ..role = MessageRole.user
            ..content = 'Message $i'
            ..tokenCount = 5
            ..createdAt = DateTime.now());
        }
      });

      // Concurrent reads
      final futures = <Future<List<Message>>>[];
      for (var i = 0; i < 5; i++) {
        futures.add(isar.messages.where().findAll());
      }

      final results = await Future.wait(futures);

      for (final result in results) {
        expect(result.length, equals(100));
      }
    });
  });
}
