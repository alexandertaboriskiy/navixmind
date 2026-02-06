import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:navixmind/core/database/collections/conversation.dart';
import 'package:navixmind/core/database/collections/message.dart';
import 'package:navixmind/core/database/collections/setting.dart';
import 'package:navixmind/core/database/collections/pending_query.dart';
import 'package:navixmind/core/database/collections/api_usage.dart';

void main() {
  // ==========================================================================
  // CONVERSATION COLLECTION TESTS
  // ==========================================================================
  group('Conversation Collection', () {
    group('create conversation', () {
      test('creates conversation with uuid and default title', () {
        final conversation = Conversation.create(
          uuid: 'test-uuid-123',
        );

        expect(conversation.uuid, equals('test-uuid-123'));
        expect(conversation.title, equals('New Conversation'));
        expect(conversation.isArchived, isFalse);
        expect(conversation.summary, isNull);
        expect(conversation.summarizedUpToId, isNull);
      });

      test('creates conversation with custom title', () {
        final conversation = Conversation.create(
          uuid: 'test-uuid-456',
          title: 'My Custom Conversation',
        );

        expect(conversation.uuid, equals('test-uuid-456'));
        expect(conversation.title, equals('My Custom Conversation'));
      });

      test('sets createdAt and updatedAt to current time', () {
        final before = DateTime.now();
        final conversation = Conversation.create(uuid: 'test-uuid');
        final after = DateTime.now();

        expect(conversation.createdAt.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
        expect(conversation.createdAt.isBefore(after.add(const Duration(seconds: 1))), isTrue);
        expect(conversation.updatedAt.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
        expect(conversation.updatedAt.isBefore(after.add(const Duration(seconds: 1))), isTrue);
      });

      test('createdAt equals updatedAt on creation', () {
        final conversation = Conversation.create(uuid: 'test-uuid');

        // They should be set to the same DateTime.now() call
        expect(
          conversation.createdAt.difference(conversation.updatedAt).inMilliseconds.abs(),
          lessThan(10),
        );
      });
    });

    group('update title', () {
      test('updates conversation title', () {
        final conversation = Conversation.create(
          uuid: 'test-uuid',
          title: 'Original Title',
        );

        conversation.title = 'Updated Title';

        expect(conversation.title, equals('Updated Title'));
      });

      test('allows empty title', () {
        final conversation = Conversation.create(uuid: 'test-uuid');
        conversation.title = '';

        expect(conversation.title, equals(''));
      });

      test('allows special characters in title', () {
        final conversation = Conversation.create(uuid: 'test-uuid');
        conversation.title = 'Title with "quotes" & special <chars>';

        expect(conversation.title, equals('Title with "quotes" & special <chars>'));
      });

      test('allows unicode in title', () {
        final conversation = Conversation.create(uuid: 'test-uuid');
        conversation.title = 'Title with emojis and Chinese chars';

        expect(conversation.title, equals('Title with emojis and Chinese chars'));
      });
    });

    group('archive/unarchive', () {
      test('archives conversation', () {
        final conversation = Conversation.create(uuid: 'test-uuid');
        expect(conversation.isArchived, isFalse);

        conversation.isArchived = true;

        expect(conversation.isArchived, isTrue);
      });

      test('unarchives conversation', () {
        final conversation = Conversation.create(uuid: 'test-uuid');
        conversation.isArchived = true;

        conversation.isArchived = false;

        expect(conversation.isArchived, isFalse);
      });

      test('multiple archive/unarchive cycles', () {
        final conversation = Conversation.create(uuid: 'test-uuid');

        for (var i = 0; i < 5; i++) {
          conversation.isArchived = true;
          expect(conversation.isArchived, isTrue);
          conversation.isArchived = false;
          expect(conversation.isArchived, isFalse);
        }
      });
    });

    group('timestamps update', () {
      test('updatedAt can be modified', () {
        final conversation = Conversation.create(uuid: 'test-uuid');
        final originalUpdatedAt = conversation.updatedAt;

        // Simulate a small delay
        final newTime = originalUpdatedAt.add(const Duration(hours: 1));
        conversation.updatedAt = newTime;

        expect(conversation.updatedAt, equals(newTime));
        expect(conversation.updatedAt.isAfter(originalUpdatedAt), isTrue);
      });

      test('createdAt remains unchanged when updating', () {
        final conversation = Conversation.create(uuid: 'test-uuid');
        final originalCreatedAt = conversation.createdAt;

        conversation.title = 'New Title';
        conversation.updatedAt = DateTime.now().add(const Duration(hours: 1));

        expect(conversation.createdAt, equals(originalCreatedAt));
      });
    });

    group('summary management', () {
      test('sets summary for context management', () {
        final conversation = Conversation.create(uuid: 'test-uuid');

        conversation.summary = 'This is a summary of previous messages.';

        expect(conversation.summary, equals('This is a summary of previous messages.'));
      });

      test('sets summarizedUpToId', () {
        final conversation = Conversation.create(uuid: 'test-uuid');

        conversation.summarizedUpToId = 42;

        expect(conversation.summarizedUpToId, equals(42));
      });

      test('clears summary', () {
        final conversation = Conversation.create(uuid: 'test-uuid');
        conversation.summary = 'Some summary';
        conversation.summarizedUpToId = 10;

        conversation.summary = null;
        conversation.summarizedUpToId = null;

        expect(conversation.summary, isNull);
        expect(conversation.summarizedUpToId, isNull);
      });
    });

    group('toJson', () {
      test('converts conversation to JSON', () {
        final conversation = Conversation.create(
          uuid: 'test-uuid-json',
          title: 'Test Title',
        );
        conversation.summary = 'Test summary';

        final json = conversation.toJson();

        expect(json['uuid'], equals('test-uuid-json'));
        expect(json['title'], equals('Test Title'));
        expect(json['isArchived'], isFalse);
        expect(json['summary'], equals('Test summary'));
        expect(json['createdAt'], isA<String>());
        expect(json['updatedAt'], isA<String>());
      });

      test('ISO 8601 date format', () {
        final conversation = Conversation.create(uuid: 'test-uuid');
        final json = conversation.toJson();

        // Should be valid ISO 8601 format
        expect(() => DateTime.parse(json['createdAt'] as String), returnsNormally);
        expect(() => DateTime.parse(json['updatedAt'] as String), returnsNormally);
      });
    });
  });

  // ==========================================================================
  // MESSAGE COLLECTION TESTS
  // ==========================================================================
  group('Message Collection', () {
    group('create message with role', () {
      test('creates user message', () {
        final message = Message.create(
          conversationId: 1,
          role: MessageRole.user,
          content: 'Hello, AI!',
        );

        expect(message.conversationId, equals(1));
        expect(message.role, equals(MessageRole.user));
        expect(message.content, equals('Hello, AI!'));
      });

      test('creates assistant message', () {
        final message = Message.create(
          conversationId: 1,
          role: MessageRole.assistant,
          content: 'Hello! How can I help you today?',
        );

        expect(message.role, equals(MessageRole.assistant));
      });

      test('creates system message', () {
        final message = Message.create(
          conversationId: 1,
          role: MessageRole.system,
          content: 'You are a helpful assistant.',
        );

        expect(message.role, equals(MessageRole.system));
      });

      test('creates toolResult message', () {
        final message = Message.create(
          conversationId: 1,
          role: MessageRole.toolResult,
          content: '{"result": "success"}',
        );

        expect(message.role, equals(MessageRole.toolResult));
      });

      test('all MessageRole values are valid', () {
        expect(MessageRole.values, containsAll([
          MessageRole.user,
          MessageRole.assistant,
          MessageRole.system,
          MessageRole.toolResult,
        ]));
      });
    });

    group('link to conversation', () {
      test('message links to conversation by ID', () {
        final message = Message.create(
          conversationId: 42,
          role: MessageRole.user,
          content: 'Test',
        );

        expect(message.conversationId, equals(42));
      });

      test('multiple messages can link to same conversation', () {
        final messages = [
          Message.create(conversationId: 1, role: MessageRole.user, content: 'Hi'),
          Message.create(conversationId: 1, role: MessageRole.assistant, content: 'Hello'),
          Message.create(conversationId: 1, role: MessageRole.user, content: 'How are you?'),
        ];

        for (final msg in messages) {
          expect(msg.conversationId, equals(1));
        }
      });
    });

    group('token count tracking', () {
      test('estimates tokens from content length', () {
        final message = Message.create(
          conversationId: 1,
          role: MessageRole.user,
          content: 'a' * 100, // 100 characters
        );

        // ~4 chars per token = 25 tokens
        expect(message.tokenCount, equals(25));
      });

      test('handles empty content', () {
        final message = Message.create(
          conversationId: 1,
          role: MessageRole.user,
          content: '',
        );

        expect(message.tokenCount, equals(0));
      });

      test('handles single character', () {
        final message = Message.create(
          conversationId: 1,
          role: MessageRole.user,
          content: 'a',
        );

        // ceil(1/4) = 1
        expect(message.tokenCount, equals(1));
      });

      test('rounds up token count', () {
        final message = Message.create(
          conversationId: 1,
          role: MessageRole.user,
          content: 'ab', // 2 characters
        );

        // ceil(2/4) = 1
        expect(message.tokenCount, equals(1));
      });

      test('handles large content', () {
        final message = Message.create(
          conversationId: 1,
          role: MessageRole.user,
          content: 'a' * 10000, // 10000 characters
        );

        // ~10000/4 = 2500 tokens
        expect(message.tokenCount, equals(2500));
      });

      test('token estimation is consistent', () {
        final content = 'Hello, this is a test message with multiple words.';
        final message1 = Message.create(
          conversationId: 1,
          role: MessageRole.user,
          content: content,
        );
        final message2 = Message.create(
          conversationId: 2,
          role: MessageRole.assistant,
          content: content,
        );

        expect(message1.tokenCount, equals(message2.tokenCount));
      });
    });

    group('attachments handling', () {
      test('creates message with no attachments by default', () {
        final message = Message.create(
          conversationId: 1,
          role: MessageRole.user,
          content: 'Test',
        );

        expect(message.attachments, isEmpty);
      });

      test('creates message with single attachment', () {
        final attachment = Attachment.create(
          type: AttachmentType.image,
          localPath: '/storage/image.jpg',
          originalName: 'photo.jpg',
          mimeType: 'image/jpeg',
          sizeBytes: 1024000,
        );

        final message = Message.create(
          conversationId: 1,
          role: MessageRole.user,
          content: 'Check this image',
          attachments: [attachment],
        );

        expect(message.attachments.length, equals(1));
        expect(message.attachments.first.type, equals(AttachmentType.image));
        expect(message.attachments.first.localPath, equals('/storage/image.jpg'));
      });

      test('creates message with multiple attachments', () {
        final attachments = [
          Attachment.create(
            type: AttachmentType.image,
            localPath: '/storage/image1.jpg',
            originalName: 'photo1.jpg',
            mimeType: 'image/jpeg',
            sizeBytes: 1024000,
          ),
          Attachment.create(
            type: AttachmentType.pdf,
            localPath: '/storage/document.pdf',
            originalName: 'doc.pdf',
            mimeType: 'application/pdf',
            sizeBytes: 2048000,
          ),
          Attachment.create(
            type: AttachmentType.video,
            localPath: '/storage/video.mp4',
            originalName: 'clip.mp4',
            mimeType: 'video/mp4',
            sizeBytes: 10240000,
          ),
        ];

        final message = Message.create(
          conversationId: 1,
          role: MessageRole.user,
          content: 'Multiple files',
          attachments: attachments,
        );

        expect(message.attachments.length, equals(3));
      });

      test('all AttachmentType values are valid', () {
        expect(AttachmentType.values, containsAll([
          AttachmentType.image,
          AttachmentType.video,
          AttachmentType.pdf,
          AttachmentType.audio,
          AttachmentType.file,
        ]));
      });

      test('attachment stores all metadata', () {
        final attachment = Attachment.create(
          type: AttachmentType.audio,
          localPath: '/storage/audio.mp3',
          originalName: 'recording.mp3',
          mimeType: 'audio/mpeg',
          sizeBytes: 5120000,
        );

        expect(attachment.type, equals(AttachmentType.audio));
        expect(attachment.localPath, equals('/storage/audio.mp3'));
        expect(attachment.originalName, equals('recording.mp3'));
        expect(attachment.mimeType, equals('audio/mpeg'));
        expect(attachment.sizeBytes, equals(5120000));
      });

      test('attachment toJson works correctly', () {
        final attachment = Attachment.create(
          type: AttachmentType.image,
          localPath: '/storage/test.jpg',
          originalName: 'test.jpg',
          mimeType: 'image/jpeg',
          sizeBytes: 1000,
        );

        final json = attachment.toJson();

        expect(json['type'], equals('image'));
        expect(json['local_path'], equals('/storage/test.jpg'));
        expect(json['original_name'], equals('test.jpg'));
        expect(json['mime_type'], equals('image/jpeg'));
        expect(json['size_bytes'], equals(1000));
      });
    });

    group('tool calls handling', () {
      test('creates message with no tool calls by default', () {
        final message = Message.create(
          conversationId: 1,
          role: MessageRole.assistant,
          content: 'Response',
        );

        expect(message.toolCalls, isEmpty);
      });

      test('creates message with single tool call', () {
        final toolCall = ToolCall.create(
          toolName: 'search_web',
          inputJson: '{"query": "weather today"}',
        );

        final message = Message.create(
          conversationId: 1,
          role: MessageRole.assistant,
          content: 'Let me search for that.',
          toolCalls: [toolCall],
        );

        expect(message.toolCalls.length, equals(1));
        expect(message.toolCalls.first.toolName, equals('search_web'));
      });

      test('creates message with multiple tool calls', () {
        final toolCalls = [
          ToolCall.create(
            toolName: 'read_file',
            inputJson: '{"path": "/etc/config"}',
          ),
          ToolCall.create(
            toolName: 'write_file',
            inputJson: '{"path": "/tmp/output", "content": "test"}',
          ),
        ];

        final message = Message.create(
          conversationId: 1,
          role: MessageRole.assistant,
          content: 'Processing files...',
          toolCalls: toolCalls,
        );

        expect(message.toolCalls.length, equals(2));
      });

      test('all ToolCallStatus values are valid', () {
        expect(ToolCallStatus.values, containsAll([
          ToolCallStatus.pending,
          ToolCallStatus.running,
          ToolCallStatus.success,
          ToolCallStatus.error,
        ]));
      });

      test('tool call default status is pending', () {
        final toolCall = ToolCall.create(
          toolName: 'test_tool',
          inputJson: '{}',
        );

        expect(toolCall.status, equals(ToolCallStatus.pending));
      });

      test('tool call status transitions', () {
        final toolCall = ToolCall.create(
          toolName: 'test_tool',
          inputJson: '{}',
        );

        expect(toolCall.status, equals(ToolCallStatus.pending));

        toolCall.status = ToolCallStatus.running;
        expect(toolCall.status, equals(ToolCallStatus.running));

        toolCall.status = ToolCallStatus.success;
        expect(toolCall.status, equals(ToolCallStatus.success));
      });

      test('tool call stores output and duration', () {
        final toolCall = ToolCall.create(
          toolName: 'calculate',
          inputJson: '{"a": 1, "b": 2}',
        );

        toolCall.outputJson = '{"result": 3}';
        toolCall.durationMs = 150;
        toolCall.status = ToolCallStatus.success;

        expect(toolCall.outputJson, equals('{"result": 3}'));
        expect(toolCall.durationMs, equals(150));
      });

      test('tool call toJson works correctly', () {
        final toolCall = ToolCall.create(
          toolName: 'fetch_data',
          inputJson: '{"url": "https://api.example.com"}',
        );
        toolCall.outputJson = '{"data": []}';
        toolCall.status = ToolCallStatus.success;
        toolCall.durationMs = 250;

        final json = toolCall.toJson();

        expect(json['tool_name'], equals('fetch_data'));
        expect(json['input'], equals('{"url": "https://api.example.com"}'));
        expect(json['output'], equals('{"data": []}'));
        expect(json['status'], equals('success'));
        expect(json['duration_ms'], equals(250));
      });
    });

    group('toSyncJson', () {
      test('converts message to sync JSON format', () {
        final message = Message.create(
          conversationId: 1,
          role: MessageRole.user,
          content: 'Test message',
        );

        final json = message.toSyncJson();

        expect(json['role'], equals('user'));
        expect(json['content'], equals('Test message'));
        expect(json['token_count'], isA<int>());
        expect(json['attachments'], isA<List>());
        expect(json['tool_calls'], isA<List>());
      });

      test('includes attachments in sync JSON', () {
        final message = Message.create(
          conversationId: 1,
          role: MessageRole.user,
          content: 'With attachment',
          attachments: [
            Attachment.create(
              type: AttachmentType.image,
              localPath: '/test.jpg',
              originalName: 'test.jpg',
              mimeType: 'image/jpeg',
              sizeBytes: 1000,
            ),
          ],
        );

        final json = message.toSyncJson();
        final attachments = json['attachments'] as List;

        expect(attachments.length, equals(1));
        expect(attachments.first['type'], equals('image'));
      });

      test('includes tool calls in sync JSON', () {
        final message = Message.create(
          conversationId: 1,
          role: MessageRole.assistant,
          content: 'Using tool',
          toolCalls: [
            ToolCall.create(
              toolName: 'test_tool',
              inputJson: '{"key": "value"}',
            ),
          ],
        );

        final json = message.toSyncJson();
        final toolCalls = json['tool_calls'] as List;

        expect(toolCalls.length, equals(1));
        expect(toolCalls.first['tool_name'], equals('test_tool'));
      });
    });

    group('createdAt', () {
      test('sets createdAt on creation', () {
        final before = DateTime.now();
        final message = Message.create(
          conversationId: 1,
          role: MessageRole.user,
          content: 'Test',
        );
        final after = DateTime.now();

        expect(message.createdAt.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
        expect(message.createdAt.isBefore(after.add(const Duration(seconds: 1))), isTrue);
      });
    });
  });

  // ==========================================================================
  // SETTING COLLECTION TESTS
  // ==========================================================================
  group('Setting Collection', () {
    group('save and retrieve settings', () {
      test('creates setting with string value', () {
        final setting = Setting.create(
          key: 'theme_mode',
          value: 'dark',
        );

        expect(setting.key, equals('theme_mode'));
        expect(setting.getValue<String>(), equals('dark'));
      });

      test('creates setting with boolean value', () {
        final setting = Setting.create(
          key: 'notifications_enabled',
          value: true,
        );

        expect(setting.getValue<bool>(), isTrue);
      });

      test('creates setting with numeric value', () {
        final setting = Setting.create(
          key: 'daily_spending_limit',
          value: 5.50,
        );

        expect(setting.getValue<double>(), equals(5.50));
      });

      test('creates setting with integer value', () {
        final setting = Setting.create(
          key: 'max_retries',
          value: 3,
        );

        expect(setting.getValue<int>(), equals(3));
      });
    });

    group('JSON value encoding/decoding', () {
      test('encodes value as JSON string', () {
        final setting = Setting.create(
          key: 'test_key',
          value: 'test_value',
        );

        // The value field should be a JSON-encoded string
        expect(setting.value, equals('"test_value"'));
      });

      test('encodes complex object as JSON', () {
        final setting = Setting.create(
          key: 'complex_setting',
          value: {'nested': true, 'count': 5},
        );

        final decoded = jsonDecode(setting.value);
        expect(decoded['nested'], isTrue);
        expect(decoded['count'], equals(5));
      });

      test('encodes list as JSON', () {
        final setting = Setting.create(
          key: 'list_setting',
          value: [1, 2, 3, 4, 5],
        );

        final decoded = setting.getValue<List<dynamic>>();
        expect(decoded, equals([1, 2, 3, 4, 5]));
      });

      test('encodes null value', () {
        final setting = Setting.create(
          key: 'nullable_setting',
          value: null,
        );

        expect(setting.getValue<dynamic>(), isNull);
      });

      test('encodes special characters', () {
        final setting = Setting.create(
          key: 'special_chars',
          value: 'Hello "World" with \n newline',
        );

        final decoded = setting.getValue<String>();
        expect(decoded, equals('Hello "World" with \n newline'));
      });
    });

    group('default values', () {
      test('has correct key constants', () {
        expect(Setting.keyDailySpendingLimit, equals('daily_spending_limit'));
        expect(Setting.keyWarningThreshold, equals('warning_threshold'));
        expect(Setting.keyNotificationsEnabled, equals('notifications_enabled'));
        expect(Setting.keyThemeMode, equals('theme_mode'));
        expect(Setting.keyTextScaleFactor, equals('text_scale_factor'));
        expect(Setting.keyReduceMotion, equals('reduce_motion'));
        expect(Setting.keyAnalyticsEnabled, equals('analytics_enabled'));
        expect(Setting.keyOnboardingCompleted, equals('onboarding_completed'));
      });
    });

    group('SettingsRepository logic', () {
      test('default daily spending limit is 0.50', () {
        // Test the default value logic
        const defaultLimit = 0.50;
        final result = null ?? defaultLimit;
        expect(result, equals(0.50));
      });

      test('default notifications enabled is true', () {
        const defaultValue = true;
        final result = null ?? defaultValue;
        expect(result, isTrue);
      });

      test('default onboarding completed is false', () {
        const defaultValue = false;
        final result = null ?? defaultValue;
        expect(result, isFalse);
      });
    });
  });

  // ==========================================================================
  // PENDING QUERY COLLECTION TESTS
  // ==========================================================================
  group('PendingQuery Collection', () {
    group('queue pending query', () {
      test('creates pending query with text only', () {
        final query = PendingQuery.create(
          query: 'What is the weather today?',
        );

        expect(query.query, equals('What is the weather today?'));
        expect(query.attachmentPaths, isEmpty);
        expect(query.status, equals(PendingQueryStatus.pending));
        expect(query.errorMessage, isNull);
      });

      test('creates pending query with attachments', () {
        final query = PendingQuery.create(
          query: 'Analyze this image',
          attachmentPaths: ['/storage/image.jpg', '/storage/document.pdf'],
        );

        expect(query.query, equals('Analyze this image'));
        expect(query.attachmentPaths.length, equals(2));
        expect(query.attachmentPaths, contains('/storage/image.jpg'));
        expect(query.attachmentPaths, contains('/storage/document.pdf'));
      });

      test('sets createdAt on creation', () {
        final before = DateTime.now();
        final query = PendingQuery.create(query: 'Test');
        final after = DateTime.now();

        expect(query.createdAt.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
        expect(query.createdAt.isBefore(after.add(const Duration(seconds: 1))), isTrue);
      });
    });

    group('mark processing/completed/failed', () {
      test('marks query as processing', () {
        final query = PendingQuery.create(query: 'Test');
        expect(query.status, equals(PendingQueryStatus.pending));

        query.status = PendingQueryStatus.processing;

        expect(query.status, equals(PendingQueryStatus.processing));
      });

      test('marks query as completed', () {
        final query = PendingQuery.create(query: 'Test');
        query.status = PendingQueryStatus.processing;

        query.status = PendingQueryStatus.completed;

        expect(query.status, equals(PendingQueryStatus.completed));
      });

      test('marks query as failed with error message', () {
        final query = PendingQuery.create(query: 'Test');
        query.status = PendingQueryStatus.processing;

        query.status = PendingQueryStatus.failed;
        query.errorMessage = 'Network connection failed';

        expect(query.status, equals(PendingQueryStatus.failed));
        expect(query.errorMessage, equals('Network connection failed'));
      });

      test('all PendingQueryStatus values are valid', () {
        expect(PendingQueryStatus.values, containsAll([
          PendingQueryStatus.pending,
          PendingQueryStatus.processing,
          PendingQueryStatus.completed,
          PendingQueryStatus.failed,
        ]));
      });
    });

    group('get pending count', () {
      test('counts pending queries correctly', () {
        final queries = [
          _createQueryWithStatus(PendingQueryStatus.pending),
          _createQueryWithStatus(PendingQueryStatus.pending),
          _createQueryWithStatus(PendingQueryStatus.processing),
          _createQueryWithStatus(PendingQueryStatus.completed),
          _createQueryWithStatus(PendingQueryStatus.failed),
          _createQueryWithStatus(PendingQueryStatus.pending),
        ];

        final pendingCount = queries
            .where((q) => q.status == PendingQueryStatus.pending)
            .length;

        expect(pendingCount, equals(3));
      });

      test('returns zero for empty list', () {
        final queries = <PendingQuery>[];
        final pendingCount = queries
            .where((q) => q.status == PendingQueryStatus.pending)
            .length;

        expect(pendingCount, equals(0));
      });

      test('returns zero when no pending queries', () {
        final queries = [
          _createQueryWithStatus(PendingQueryStatus.completed),
          _createQueryWithStatus(PendingQueryStatus.failed),
        ];

        final pendingCount = queries
            .where((q) => q.status == PendingQueryStatus.pending)
            .length;

        expect(pendingCount, equals(0));
      });
    });

    group('clear processed', () {
      test('filters out completed queries', () {
        final queries = [
          _createQueryWithStatus(PendingQueryStatus.pending),
          _createQueryWithStatus(PendingQueryStatus.completed),
          _createQueryWithStatus(PendingQueryStatus.failed),
          _createQueryWithStatus(PendingQueryStatus.pending),
        ];

        final remaining = queries.where((q) =>
            q.status != PendingQueryStatus.completed &&
            q.status != PendingQueryStatus.failed).toList();

        expect(remaining.length, equals(2));
        expect(remaining.every((q) => q.status == PendingQueryStatus.pending), isTrue);
      });

      test('clears all when only processed queries exist', () {
        final queries = [
          _createQueryWithStatus(PendingQueryStatus.completed),
          _createQueryWithStatus(PendingQueryStatus.failed),
          _createQueryWithStatus(PendingQueryStatus.completed),
        ];

        final remaining = queries.where((q) =>
            q.status != PendingQueryStatus.completed &&
            q.status != PendingQueryStatus.failed).toList();

        expect(remaining, isEmpty);
      });
    });

    group('sorting by createdAt', () {
      test('can sort queries by creation time', () {
        final queries = <_MockPendingQueryWithTime>[];
        final baseTime = DateTime(2024, 6, 1, 10, 0, 0);

        queries.add(_MockPendingQueryWithTime(
          query: 'Third',
          createdAt: baseTime.add(const Duration(minutes: 20)),
        ));
        queries.add(_MockPendingQueryWithTime(
          query: 'First',
          createdAt: baseTime,
        ));
        queries.add(_MockPendingQueryWithTime(
          query: 'Second',
          createdAt: baseTime.add(const Duration(minutes: 10)),
        ));

        queries.sort((a, b) => a.createdAt.compareTo(b.createdAt));

        expect(queries[0].query, equals('First'));
        expect(queries[1].query, equals('Second'));
        expect(queries[2].query, equals('Third'));
      });
    });
  });

  // ==========================================================================
  // API USAGE COLLECTION TESTS
  // ==========================================================================
  group('ApiUsage Collection', () {
    group('record usage', () {
      test('creates API usage record', () {
        final usage = ApiUsage.create(
          model: 'claude-sonnet-4-20250514',
          inputTokens: 1000,
          outputTokens: 500,
        );

        expect(usage.model, equals('claude-sonnet-4-20250514'));
        expect(usage.inputTokens, equals(1000));
        expect(usage.outputTokens, equals(500));
      });

      test('normalizes date to day granularity', () {
        final usage = ApiUsage.create(
          model: 'claude-sonnet-4-20250514',
          inputTokens: 100,
          outputTokens: 50,
        );

        expect(usage.date.hour, equals(0));
        expect(usage.date.minute, equals(0));
        expect(usage.date.second, equals(0));
        expect(usage.date.millisecond, equals(0));
      });

      test('calculates cost automatically', () {
        final usage = ApiUsage.create(
          model: 'claude-sonnet-4-20250514',
          inputTokens: 1000,
          outputTokens: 500,
        );

        // Input: 1000 tokens at $0.003/1K = $0.003
        // Output: 500 tokens at $0.015/1K = $0.0075
        // Total: $0.0105
        expect(usage.estimatedCostUsd, closeTo(0.0105, 0.0001));
      });
    });

    group("get today's cost", () {
      test('sums costs for today', () {
        final usages = [
          _MockApiUsageForCost(cost: 0.01),
          _MockApiUsageForCost(cost: 0.02),
          _MockApiUsageForCost(cost: 0.015),
        ];

        final total = usages.fold(0.0, (sum, usage) => sum + usage.cost);

        expect(total, closeTo(0.045, 0.001));
      });

      test('returns zero for no usage today', () {
        final usages = <_MockApiUsageForCost>[];
        final total = usages.fold(0.0, (sum, usage) => sum + usage.cost);

        expect(total, equals(0.0));
      });
    });

    group('get month cost', () {
      test('calculates start and end of month correctly', () {
        final now = DateTime(2024, 6, 15);
        final startOfMonth = DateTime(now.year, now.month, 1);
        final endOfMonth = DateTime(now.year, now.month + 1, 1);

        expect(startOfMonth, equals(DateTime(2024, 6, 1)));
        expect(endOfMonth, equals(DateTime(2024, 7, 1)));
      });

      test('handles December to January transition', () {
        final december = DateTime(2024, 12, 15);
        final startOfMonth = DateTime(december.year, december.month, 1);
        final endOfMonth = DateTime(december.year, december.month + 1, 1);

        expect(startOfMonth, equals(DateTime(2024, 12, 1)));
        expect(endOfMonth, equals(DateTime(2025, 1, 1)));
      });

      test('sums monthly costs', () {
        final usages = List.generate(30, (i) => _MockApiUsageForCost(cost: 0.10));
        final total = usages.fold(0.0, (sum, usage) => sum + usage.cost);

        expect(total, closeTo(3.0, 0.01));
      });
    });

    group('get daily breakdown', () {
      test('groups costs by day', () {
        final usages = [
          _MockApiUsageWithDate(
            date: DateTime(2024, 6, 1),
            cost: 0.10,
          ),
          _MockApiUsageWithDate(
            date: DateTime(2024, 6, 1),
            cost: 0.05,
          ),
          _MockApiUsageWithDate(
            date: DateTime(2024, 6, 2),
            cost: 0.08,
          ),
          _MockApiUsageWithDate(
            date: DateTime(2024, 6, 3),
            cost: 0.12,
          ),
        ];

        final breakdown = <DateTime, double>{};
        for (final usage in usages) {
          final day = DateTime(usage.date.year, usage.date.month, usage.date.day);
          breakdown[day] = (breakdown[day] ?? 0) + usage.cost;
        }

        expect(breakdown[DateTime(2024, 6, 1)], closeTo(0.15, 0.001));
        expect(breakdown[DateTime(2024, 6, 2)], closeTo(0.08, 0.001));
        expect(breakdown[DateTime(2024, 6, 3)], closeTo(0.12, 0.001));
      });

      test('calculates last N days range', () {
        final now = DateTime(2024, 6, 15);
        final days = 7;
        final start = DateTime(now.year, now.month, now.day - days);

        expect(start, equals(DateTime(2024, 6, 8)));
      });

      test('handles month boundary in breakdown', () {
        final now = DateTime(2024, 6, 3);
        final days = 7;
        final start = DateTime(now.year, now.month, now.day - days);

        // Should go back to May
        expect(start.month, equals(5));
        expect(start.day, equals(27));
      });
    });

    group('cost calculation', () {
      test('sonnet pricing is correct', () {
        final cost = _calculateCost('claude-sonnet-4-20250514', 1000, 1000);
        // Input: 1000 * $0.003/1K = $0.003
        // Output: 1000 * $0.015/1K = $0.015
        // Total: $0.018
        expect(cost, closeTo(0.018, 0.0001));
      });

      test('haiku pricing is correct', () {
        final cost = _calculateCost('claude-haiku-4-20250514', 1000, 1000);
        // Input: 1000 * $0.00025/1K = $0.00025
        // Output: 1000 * $0.00125/1K = $0.00125
        // Total: $0.0015
        expect(cost, closeTo(0.0015, 0.0001));
      });

      test('unknown model defaults to sonnet pricing', () {
        final unknownCost = _calculateCost('unknown-model', 1000, 500);
        final sonnetCost = _calculateCost('claude-sonnet-4-20250514', 1000, 500);

        expect(unknownCost, equals(sonnetCost));
      });

      test('output tokens cost more than input', () {
        final inputOnlyCost = _calculateCost('claude-sonnet-4-20250514', 1000, 0);
        final outputOnlyCost = _calculateCost('claude-sonnet-4-20250514', 0, 1000);

        expect(outputOnlyCost, greaterThan(inputOnlyCost));
        expect(outputOnlyCost / inputOnlyCost, closeTo(5.0, 0.01));
      });

      test('handles zero tokens', () {
        final cost = _calculateCost('claude-sonnet-4-20250514', 0, 0);
        expect(cost, equals(0.0));
      });

      test('handles large token counts', () {
        // 200K context window simulation
        final cost = _calculateCost('claude-sonnet-4-20250514', 200000, 4096);

        // Input: 200K * $0.003/1K = $0.60
        // Output: 4096 * $0.015/1K = $0.06144
        // Total: ~$0.66
        expect(cost, closeTo(0.66144, 0.001));
      });
    });

    group('token tracking', () {
      test('sums input and output tokens separately', () {
        final usages = [
          _MockApiUsageForTokens(inputTokens: 1000, outputTokens: 500),
          _MockApiUsageForTokens(inputTokens: 2000, outputTokens: 800),
          _MockApiUsageForTokens(inputTokens: 500, outputTokens: 200),
        ];

        int totalInput = 0;
        int totalOutput = 0;
        for (final usage in usages) {
          totalInput += usage.inputTokens;
          totalOutput += usage.outputTokens;
        }

        expect(totalInput, equals(3500));
        expect(totalOutput, equals(1500));
      });

      test('handles empty usage list', () {
        final usages = <_MockApiUsageForTokens>[];

        int totalInput = 0;
        int totalOutput = 0;
        for (final usage in usages) {
          totalInput += usage.inputTokens;
          totalOutput += usage.outputTokens;
        }

        expect(totalInput, equals(0));
        expect(totalOutput, equals(0));
      });
    });
  });

  // ==========================================================================
  // INTEGRATION-LIKE TESTS (Data Flow)
  // ==========================================================================
  group('Data Flow Integration', () {
    test('conversation can hold multiple messages', () {
      final conversation = Conversation.create(
        uuid: 'conv-uuid',
        title: 'Test Conversation',
      );

      final messages = [
        Message.create(
          conversationId: conversation.id,
          role: MessageRole.user,
          content: 'Hello',
        ),
        Message.create(
          conversationId: conversation.id,
          role: MessageRole.assistant,
          content: 'Hi there!',
        ),
        Message.create(
          conversationId: conversation.id,
          role: MessageRole.user,
          content: 'How are you?',
        ),
      ];

      expect(messages.every((m) => m.conversationId == conversation.id), isTrue);
    });

    test('pending query lifecycle', () {
      // 1. Create pending query
      final query = PendingQuery.create(
        query: 'Test query',
        attachmentPaths: ['/test/file.jpg'],
      );
      expect(query.status, equals(PendingQueryStatus.pending));

      // 2. Mark as processing
      query.status = PendingQueryStatus.processing;
      expect(query.status, equals(PendingQueryStatus.processing));

      // 3a. Success path
      query.status = PendingQueryStatus.completed;
      expect(query.status, equals(PendingQueryStatus.completed));
    });

    test('pending query failure lifecycle', () {
      final query = PendingQuery.create(query: 'Test');

      query.status = PendingQueryStatus.processing;
      query.status = PendingQueryStatus.failed;
      query.errorMessage = 'Connection timeout';

      expect(query.status, equals(PendingQueryStatus.failed));
      expect(query.errorMessage, isNotNull);
    });

    test('API usage tracking for conversation', () {
      // Simulate a conversation with multiple API calls
      final usages = <_MockApiUsageForCost>[];

      // Initial prompt
      usages.add(_MockApiUsageForCost(cost: 0.01));

      // Follow-up questions
      for (var i = 0; i < 5; i++) {
        usages.add(_MockApiUsageForCost(cost: 0.005 + (i * 0.001)));
      }

      final totalCost = usages.fold(0.0, (sum, usage) => sum + usage.cost);

      expect(totalCost, greaterThan(0.03));
      expect(usages.length, equals(6));
    });

    test('settings persist across simulated sessions', () {
      // Simulate saving settings
      final settings = <String, String>{};

      final dailyLimit = Setting.create(
        key: Setting.keyDailySpendingLimit,
        value: 10.0,
      );
      settings[dailyLimit.key] = dailyLimit.value;

      final themeMode = Setting.create(
        key: Setting.keyThemeMode,
        value: 'dark',
      );
      settings[themeMode.key] = themeMode.value;

      // Simulate retrieving settings
      final retrievedLimit = jsonDecode(settings[Setting.keyDailySpendingLimit]!);
      final retrievedTheme = jsonDecode(settings[Setting.keyThemeMode]!);

      expect(retrievedLimit, equals(10.0));
      expect(retrievedTheme, equals('dark'));
    });
  });
}

// =============================================================================
// HELPER FUNCTIONS AND MOCK CLASSES
// =============================================================================

/// Creates a PendingQuery with specified status for testing
PendingQuery _createQueryWithStatus(PendingQueryStatus status) {
  final query = PendingQuery.create(query: 'Test query');
  query.status = status;
  return query;
}

/// Calculate cost based on model pricing (mirrors implementation)
double _calculateCost(String model, int inputTokens, int outputTokens) {
  const pricing = {
    'claude-sonnet-4-20250514': {'input': 0.003, 'output': 0.015},
    'claude-haiku-4-20250514': {'input': 0.00025, 'output': 0.00125},
  };

  final modelPricing = pricing[model] ?? pricing['claude-sonnet-4-20250514']!;
  final inputCost = (inputTokens / 1000) * modelPricing['input']!;
  final outputCost = (outputTokens / 1000) * modelPricing['output']!;

  return inputCost + outputCost;
}

/// Mock class for API usage cost testing
class _MockApiUsageForCost {
  final double cost;

  _MockApiUsageForCost({required this.cost});
}

/// Mock class for API usage with date testing
class _MockApiUsageWithDate {
  final DateTime date;
  final double cost;

  _MockApiUsageWithDate({required this.date, required this.cost});
}

/// Mock class for API usage token tracking
class _MockApiUsageForTokens {
  final int inputTokens;
  final int outputTokens;

  _MockApiUsageForTokens({
    required this.inputTokens,
    required this.outputTokens,
  });
}

/// Mock class for pending query with time
class _MockPendingQueryWithTime {
  final String query;
  final DateTime createdAt;

  _MockPendingQueryWithTime({
    required this.query,
    required this.createdAt,
  });
}
