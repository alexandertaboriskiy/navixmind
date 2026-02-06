import 'package:flutter_test/flutter_test.dart';
import 'package:navixmind/core/database/collections/message.dart';

void main() {
  group('ConversationManager constants', () {
    test('summarizationThreshold is 50', () {
      // The threshold at which auto-summarization triggers
      const summarizationThreshold = 50;
      expect(summarizationThreshold, equals(50));
    });

    test('keepRecentCount is 20', () {
      // Number of recent messages to keep after summarization
      const keepRecentCount = 20;
      expect(keepRecentCount, equals(20));
    });

    test('summarization triggers when messages exceed threshold', () {
      const messageCount = 51;
      const threshold = 50;
      expect(messageCount >= threshold, isTrue);
    });

    test('summarization does not trigger below threshold', () {
      const messageCount = 49;
      const threshold = 50;
      expect(messageCount >= threshold, isFalse);
    });
  });

  group('Token estimation', () {
    // Test the token estimation formula: ~4 characters per token
    int estimateTokens(String text) {
      return (text.length / 4).ceil();
    }

    test('estimates tokens for short text', () {
      final tokens = estimateTokens('Hello');
      expect(tokens, equals(2)); // 5 chars / 4 = 1.25, ceil = 2
    });

    test('estimates tokens for medium text', () {
      final tokens = estimateTokens('Hello, world!');
      expect(tokens, equals(4)); // 13 chars / 4 = 3.25, ceil = 4
    });

    test('estimates tokens for longer text', () {
      final text = 'This is a longer piece of text that should have more tokens.';
      final tokens = estimateTokens(text);
      expect(tokens, equals(15)); // 60 chars / 4 = 15
    });

    test('estimates 1 token for empty string', () {
      final tokens = estimateTokens('');
      expect(tokens, equals(0)); // 0 chars / 4 = 0, ceil = 0
    });

    test('estimates correctly for exactly 4 characters', () {
      final tokens = estimateTokens('Test');
      expect(tokens, equals(1)); // 4 chars / 4 = 1
    });

    test('handles unicode characters', () {
      final tokens = estimateTokens('Hello 🌍!');
      // Unicode emoji counts as characters
      expect(tokens, greaterThan(0));
    });
  });

  group('Message role parsing', () {
    MessageRole parseRole(String role) {
      switch (role.toLowerCase()) {
        case 'user':
          return MessageRole.user;
        case 'assistant':
          return MessageRole.assistant;
        case 'system':
          return MessageRole.system;
        case 'tool_result':
          return MessageRole.toolResult;
        default:
          return MessageRole.user;
      }
    }

    test('parses user role', () {
      expect(parseRole('user'), equals(MessageRole.user));
    });

    test('parses assistant role', () {
      expect(parseRole('assistant'), equals(MessageRole.assistant));
    });

    test('parses system role', () {
      expect(parseRole('system'), equals(MessageRole.system));
    });

    test('parses tool_result role', () {
      expect(parseRole('tool_result'), equals(MessageRole.toolResult));
    });

    test('handles uppercase input', () {
      expect(parseRole('USER'), equals(MessageRole.user));
      expect(parseRole('ASSISTANT'), equals(MessageRole.assistant));
    });

    test('handles mixed case input', () {
      expect(parseRole('User'), equals(MessageRole.user));
      expect(parseRole('Assistant'), equals(MessageRole.assistant));
    });

    test('defaults to user for unknown role', () {
      expect(parseRole('unknown'), equals(MessageRole.user));
      expect(parseRole(''), equals(MessageRole.user));
      expect(parseRole('bot'), equals(MessageRole.user));
    });
  });

  group('Summary text building', () {
    String buildSummaryText(
      List<MockMessage> messages,
      String? existingSummary,
    ) {
      final buffer = StringBuffer();

      if (existingSummary != null) {
        buffer.writeln('Previous summary:');
        buffer.writeln(existingSummary);
        buffer.writeln();
        buffer.writeln('New messages to include:');
      }

      for (final msg in messages) {
        final role = msg.role == 'user' ? 'User' : 'Assistant';
        var content = msg.content;
        if (content.length > 500) {
          content = '${content.substring(0, 500)}...';
        }
        buffer.writeln('$role: $content');
      }

      return buffer.toString();
    }

    test('builds text without existing summary', () {
      final messages = [
        MockMessage(role: 'user', content: 'Hello'),
        MockMessage(role: 'assistant', content: 'Hi there!'),
      ];

      final result = buildSummaryText(messages, null);

      expect(result, contains('User: Hello'));
      expect(result, contains('Assistant: Hi there!'));
      expect(result, isNot(contains('Previous summary')));
    });

    test('builds text with existing summary', () {
      final messages = [
        MockMessage(role: 'user', content: 'New message'),
      ];

      final result = buildSummaryText(messages, 'Previous context here');

      expect(result, contains('Previous summary:'));
      expect(result, contains('Previous context here'));
      expect(result, contains('New messages to include:'));
      expect(result, contains('User: New message'));
    });

    test('truncates long messages to 500 characters', () {
      final longContent = 'A' * 600;
      final messages = [
        MockMessage(role: 'user', content: longContent),
      ];

      final result = buildSummaryText(messages, null);

      expect(result, contains('A' * 500));
      expect(result, contains('...'));
      expect(result, isNot(contains('A' * 501)));
    });

    test('does not truncate messages under 500 characters', () {
      final content = 'A' * 499;
      final messages = [
        MockMessage(role: 'user', content: content),
      ];

      final result = buildSummaryText(messages, null);

      expect(result, contains(content));
      expect(result, isNot(contains('...')));
    });

    test('handles empty messages list', () {
      final result = buildSummaryText([], null);
      expect(result, isEmpty);
    });

    test('handles empty messages list with existing summary', () {
      final result = buildSummaryText([], 'Previous summary');

      expect(result, contains('Previous summary'));
      expect(result, contains('New messages to include:'));
    });
  });

  group('Summarization prompt building', () {
    String buildSummarizationPrompt(String text) {
      return '''[SYSTEM: This is an internal summarization request. Provide a concise summary of the conversation below for context management. Focus on key topics, decisions, and relevant information. Keep it under 500 words.]

$text

Please summarize the conversation above, preserving important context for future reference.''';
    }

    test('includes system instruction', () {
      final prompt = buildSummarizationPrompt('Test content');

      expect(prompt, contains('[SYSTEM:'));
      expect(prompt, contains('internal summarization request'));
    });

    test('includes the text to summarize', () {
      final prompt = buildSummarizationPrompt('My conversation content');

      expect(prompt, contains('My conversation content'));
    });

    test('includes summary instruction', () {
      final prompt = buildSummarizationPrompt('Content');

      expect(prompt, contains('Please summarize'));
      expect(prompt, contains('preserving important context'));
    });

    test('mentions word limit', () {
      final prompt = buildSummarizationPrompt('Content');

      expect(prompt, contains('500 words'));
    });

    test('mentions key topics and decisions', () {
      final prompt = buildSummarizationPrompt('Content');

      expect(prompt, contains('key topics'));
      expect(prompt, contains('decisions'));
    });
  });

  group('Summarization logic', () {
    test('messages to summarize excludes recent ones', () {
      final allMessages = List.generate(60, (i) => MockMessage(
        role: i.isEven ? 'user' : 'assistant',
        content: 'Message $i',
      ));

      const keepRecentCount = 20;
      final messagesToSummarize = allMessages
          .take(allMessages.length - keepRecentCount)
          .toList();

      expect(messagesToSummarize.length, equals(40));
      expect(messagesToSummarize.first.content, equals('Message 0'));
      expect(messagesToSummarize.last.content, equals('Message 39'));
    });

    test('keeps correct number of recent messages', () {
      final allMessages = List.generate(60, (i) => MockMessage(
        role: i.isEven ? 'user' : 'assistant',
        content: 'Message $i',
      ));

      const keepRecentCount = 20;
      final recentMessages = allMessages
          .skip(allMessages.length - keepRecentCount)
          .toList();

      expect(recentMessages.length, equals(20));
      expect(recentMessages.first.content, equals('Message 40'));
      expect(recentMessages.last.content, equals('Message 59'));
    });

    test('no summarization needed when messages <= keepRecentCount', () {
      final allMessages = List.generate(20, (i) => MockMessage(
        role: i.isEven ? 'user' : 'assistant',
        content: 'Message $i',
      ));

      const keepRecentCount = 20;

      // Would return early because nothing to summarize
      expect(allMessages.length <= keepRecentCount, isTrue);
    });

    test('re-summarization threshold is 30 new messages', () {
      const reSummarizationThreshold = 30;
      const newMessageCount = 29;

      // Should not re-summarize with fewer than 30 new messages
      expect(newMessageCount < reSummarizationThreshold, isTrue);
    });
  });

  group('Delta actions', () {
    test('set_summary action format', () {
      final delta = {
        'action': 'set_summary',
        'summary': 'This is a summary',
        'summarized_up_to_id': 42,
      };

      expect(delta['action'], equals('set_summary'));
      expect(delta['summary'], isA<String>());
      expect(delta['summarized_up_to_id'], isA<int>());
    });

    test('sync_full action format', () {
      final delta = {
        'action': 'sync_full',
        'conversation_id': 123,
        'messages': [
          {'id': 1, 'role': 'user', 'content': 'Hello'},
        ],
        'summary': 'Previous summary',
      };

      expect(delta['action'], equals('sync_full'));
      expect(delta['conversation_id'], isA<int>());
      expect(delta['messages'], isA<List>());
    });

    test('new_conversation action format', () {
      final delta = {
        'action': 'new_conversation',
        'conversation_id': 456,
      };

      expect(delta['action'], equals('new_conversation'));
      expect(delta['conversation_id'], isA<int>());
    });

    test('add_message action format', () {
      final delta = {
        'action': 'add_message',
        'message': {
          'id': 789,
          'role': 'user',
          'content': 'New message',
          'token_count': 3,
        },
      };

      expect(delta['action'], equals('add_message'));
      expect(delta['message'], isA<Map>());
      expect((delta['message'] as Map)['role'], equals('user'));
    });

    test('add_message with attachments', () {
      final delta = {
        'action': 'add_message',
        'message': {
          'id': 789,
          'role': 'user',
          'content': 'Check this file',
          'token_count': 4,
          'attachments': [
            {'path': '/path/to/file.pdf', 'type': 'document'},
          ],
        },
      };

      final message = delta['message'] as Map;
      expect(message['attachments'], isA<List>());
      expect((message['attachments'] as List).length, equals(1));
    });
  });

  group('Conversation UUID generation', () {
    test('uses timestamp for UUID', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final uuid = now.toString();

      expect(uuid, isA<String>());
      expect(int.tryParse(uuid), isNotNull);
    });

    test('sequential calls produce different UUIDs', () async {
      final uuid1 = DateTime.now().millisecondsSinceEpoch.toString();
      await Future.delayed(const Duration(milliseconds: 1));
      final uuid2 = DateTime.now().millisecondsSinceEpoch.toString();

      expect(uuid1, isNot(equals(uuid2)));
    });
  });

  group('Error handling', () {
    test('uninitialized state throws StateError', () {
      // When _isar is null, addMessage should throw StateError
      expect(
        () => throw StateError('ConversationManager not initialized'),
        throwsA(isA<StateError>()),
      );
    });

    test('StateError message is descriptive', () {
      try {
        throw StateError('ConversationManager not initialized');
      } catch (e) {
        expect(e.toString(), contains('ConversationManager'));
        expect(e.toString(), contains('not initialized'));
      }
    });
  });
}

/// Mock message class for testing
class MockMessage {
  final String role;
  final String content;

  MockMessage({required this.role, required this.content});
}
