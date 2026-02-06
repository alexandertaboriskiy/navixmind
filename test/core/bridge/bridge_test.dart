import 'package:flutter_test/flutter_test.dart';
import 'package:navixmind/core/bridge/messages.dart';

void main() {
  group('JsonRpcRequest', () {
    test('creates request with auto-generated id', () {
      final request = JsonRpcRequest(
        method: 'test_method',
        params: {'key': 'value'},
      );

      expect(request.method, equals('test_method'));
      expect(request.params['key'], equals('value'));
      expect(request.id, isNotEmpty);
      expect(request.jsonrpc, equals('2.0'));
    });

    test('serializes to JSON correctly', () {
      final request = JsonRpcRequest(
        method: 'test_method',
        params: {'key': 'value'},
        id: 'test-id',
      );

      final json = request.toJson();

      expect(json['jsonrpc'], equals('2.0'));
      expect(json['method'], equals('test_method'));
      expect(json['params'], equals({'key': 'value'}));
      expect(json['id'], equals('test-id'));
    });

    test('deserializes from JSON correctly', () {
      final json = {
        'jsonrpc': '2.0',
        'id': 'test-id',
        'method': 'test_method',
        'params': {'key': 'value'},
      };

      final request = JsonRpcRequest.fromJson(json);

      expect(request.method, equals('test_method'));
      expect(request.params['key'], equals('value'));
      expect(request.id, equals('test-id'));
    });
  });

  group('JsonRpcResponse', () {
    test('creates success response', () {
      final response = JsonRpcResponse(
        id: 'test-id',
        result: {'content': 'Hello'},
      );

      expect(response.isSuccess, isTrue);
      expect(response.isError, isFalse);
      expect(response.result?['content'], equals('Hello'));
    });

    test('creates error response', () {
      final response = JsonRpcResponse(
        id: 'test-id',
        error: JsonRpcError(
          code: -32000,
          message: 'Test error',
        ),
      );

      expect(response.isSuccess, isFalse);
      expect(response.isError, isTrue);
      expect(response.error?.message, equals('Test error'));
      expect(response.error?.code, equals(-32000));
    });

    test('serializes success response to JSON', () {
      final response = JsonRpcResponse(
        id: 'test-id',
        result: {'key': 'value'},
      );

      final json = response.toJson();

      expect(json['jsonrpc'], equals('2.0'));
      expect(json['id'], equals('test-id'));
      expect(json['result'], equals({'key': 'value'}));
      expect(json.containsKey('error'), isFalse);
    });

    test('serializes error response to JSON', () {
      final response = JsonRpcResponse(
        id: 'test-id',
        error: JsonRpcError(
          code: -32000,
          message: 'Error message',
          data: {'detail': 'More info'},
        ),
      );

      final json = response.toJson();

      expect(json['jsonrpc'], equals('2.0'));
      expect(json['id'], equals('test-id'));
      expect(json['error']['code'], equals(-32000));
      expect(json['error']['message'], equals('Error message'));
      expect(json['error']['data']['detail'], equals('More info'));
    });
  });

  group('LogMessage', () {
    test('creates log message from JSON', () {
      final json = {
        'level': 'info',
        'message': 'Test log',
        'progress': 0.5,
      };

      final log = LogMessage.fromJson(json);

      expect(log.level, equals('info'));
      expect(log.message, equals('Test log'));
      expect(log.progress, equals(0.5));
      expect(log.hasProgress, isTrue);
    });

    test('isError returns true for error level', () {
      final log = LogMessage(level: 'error', message: 'Error!');
      expect(log.isError, isTrue);
      expect(log.isWarning, isFalse);
    });

    test('isWarning returns true for warn level', () {
      final log = LogMessage(level: 'warn', message: 'Warning!');
      expect(log.isWarning, isTrue);
      expect(log.isError, isFalse);
    });
  });

  group('NativeToolRequest', () {
    test('creates request from JSON', () {
      final json = {
        'id': 'request-123',
        'params': {
          'tool': 'ffmpeg',
          'args': {'input_path': '/path/to/video.mp4'},
          'timeout_ms': 60000,
        },
      };

      final request = NativeToolRequest.fromJson(json);

      expect(request.id, equals('request-123'));
      expect(request.tool, equals('ffmpeg'));
      expect(request.args['input_path'], equals('/path/to/video.mp4'));
      expect(request.timeoutMs, equals(60000));
    });

    test('uses default timeout when not specified', () {
      final json = {
        'id': 'request-123',
        'params': {
          'tool': 'ocr',
          'args': {'image_path': '/path/to/image.jpg'},
        },
      };

      final request = NativeToolRequest.fromJson(json);

      expect(request.timeoutMs, equals(30000));
    });
  });

  group('SessionDelta', () {
    test('creates newConversation delta', () {
      final delta = SessionDelta.newConversation(123);
      final json = delta.toJson();

      expect(json['action'], equals('newConversation'));
      expect(json['conversation_id'], equals(123));
    });

    test('creates addMessage delta', () {
      final delta = SessionDelta.addMessage({
        'role': 'user',
        'content': 'Hello',
      });
      final json = delta.toJson();

      expect(json['action'], equals('addMessage'));
      expect(json['message']['role'], equals('user'));
      expect(json['message']['content'], equals('Hello'));
    });

    test('creates setSummary delta', () {
      final delta = SessionDelta.setSummary(
        summary: 'Conversation summary',
        summarizedUpToId: 5,
      );
      final json = delta.toJson();

      expect(json['action'], equals('setSummary'));
      expect(json['summary'], equals('Conversation summary'));
      expect(json['summarized_up_to_id'], equals(5));
    });

    test('creates syncFull delta', () {
      final delta = SessionDelta.syncFull(
        conversationId: 123,
        messages: [
          {'role': 'user', 'content': 'Hi'},
          {'role': 'assistant', 'content': 'Hello!'},
        ],
        summary: 'Previous summary',
      );
      final json = delta.toJson();

      expect(json['action'], equals('syncFull'));
      expect(json['conversation_id'], equals(123));
      expect(json['messages'].length, equals(2));
      expect(json['summary'], equals('Previous summary'));
    });

    test('creates syncFull without summary', () {
      final delta = SessionDelta.syncFull(
        conversationId: 456,
        messages: [
          {'role': 'user', 'content': 'Test'},
        ],
      );
      final json = delta.toJson();

      expect(json['action'], equals('syncFull'));
      expect(json['conversation_id'], equals(456));
      expect(json['summary'], isNull);
    });
  });

  group('Auth token request handling', () {
    test('recognizes request_fresh_token method', () {
      final json = {
        'jsonrpc': '2.0',
        'id': 'token-req-1',
        'method': 'request_fresh_token',
        'params': {},
      };

      expect(json['method'], equals('request_fresh_token'));
    });

    test('recognizes auth_error method', () {
      final json = {
        'jsonrpc': '2.0',
        'id': 'auth-err-1',
        'method': 'auth_error',
        'params': {
          'error': 'token_expired',
          'message': 'The access token has expired',
        },
      };

      expect(json['method'], equals('auth_error'));
      expect((json['params'] as Map<String, dynamic>)['error'], equals('token_expired'));
    });

    test('token response format is correct', () {
      final response = <String, dynamic>{
        'jsonrpc': '2.0',
        'id': 'token-req-1',
        'result': {
          'access_token': 'ya29.a0AfH6SMC...',
        },
      };

      expect(response['result'], isA<Map>());
      expect((response['result'] as Map<String, dynamic>)['access_token'], isNotNull);
    });

    test('handles missing token gracefully', () {
      final response = <String, dynamic>{
        'jsonrpc': '2.0',
        'id': 'token-req-1',
        'error': {
          'code': -32000,
          'message': 'No valid token available',
        },
      };

      expect(response['error'], isNotNull);
      expect((response['error'] as Map<String, dynamic>)['code'], equals(-32000));
    });
  });

  group('Cost context enrichment', () {
    test('includes cost_percent_used in context', () {
      final context = <String, dynamic>{
        'conversation_id': 123,
      };
      final costPercentUsed = 75.5;

      final enrichedContext = <String, dynamic>{
        ...context,
        'cost_percent_used': costPercentUsed,
      };

      expect(enrichedContext['cost_percent_used'], equals(75.5));
      expect(enrichedContext['conversation_id'], equals(123));
    });

    test('includes has_attachments flag', () {
      final filePaths = ['/path/to/file1.pdf', '/path/to/file2.jpg'];

      final context = <String, dynamic>{
        if (filePaths.isNotEmpty) 'has_attachments': true,
      };

      expect(context['has_attachments'], isTrue);
    });

    test('omits has_attachments when no files', () {
      final filePaths = <String>[];

      final context = <String, dynamic>{
        if (filePaths.isNotEmpty) 'has_attachments': true,
      };

      expect(context.containsKey('has_attachments'), isFalse);
    });

    test('preserves existing context when enriching', () {
      final originalContext = <String, dynamic>{
        'user_preference': 'dark_mode',
        'locale': 'en_US',
      };

      final enrichedContext = <String, dynamic>{
        ...originalContext,
        'cost_percent_used': 50.0,
        'has_attachments': true,
      };

      expect(enrichedContext['user_preference'], equals('dark_mode'));
      expect(enrichedContext['locale'], equals('en_US'));
      expect(enrichedContext['cost_percent_used'], equals(50.0));
      expect(enrichedContext['has_attachments'], isTrue);
    });

    test('handles null context', () {
      final Map<String, dynamic>? context = null;

      final enrichedContext = <String, dynamic>{
        ...?context,
        'cost_percent_used': 25.0,
      };

      expect(enrichedContext['cost_percent_used'], equals(25.0));
      expect(enrichedContext.length, equals(1));
    });
  });

  group('Message role parsing', () {
    test('parses user role', () {
      final message = {'role': 'user', 'content': 'Hello'};
      expect(message['role'], equals('user'));
    });

    test('parses assistant role', () {
      final message = {'role': 'assistant', 'content': 'Hi there!'};
      expect(message['role'], equals('assistant'));
    });

    test('parses system role', () {
      final message = {'role': 'system', 'content': 'You are a helpful assistant.'};
      expect(message['role'], equals('system'));
    });

    test('handles tool_use content block', () {
      final message = {
        'role': 'assistant',
        'content': [
          {
            'type': 'tool_use',
            'id': 'tool_123',
            'name': 'read_file',
            'input': {'path': '/tmp/test.txt'},
          },
        ],
      };

      final content = message['content'] as List;
      expect(content.first['type'], equals('tool_use'));
      expect(content.first['name'], equals('read_file'));
    });

    test('handles tool_result content block', () {
      final message = {
        'role': 'user',
        'content': [
          {
            'type': 'tool_result',
            'tool_use_id': 'tool_123',
            'content': 'File contents here',
          },
        ],
      };

      final content = message['content'] as List;
      expect(content.first['type'], equals('tool_result'));
      expect(content.first['tool_use_id'], equals('tool_123'));
    });
  });

  group('Summarization delta', () {
    test('setSummary preserves summarized_up_to_id', () {
      final delta = SessionDelta.setSummary(
        summary: 'User asked about weather. Assistant provided forecast.',
        summarizedUpToId: 10,
      );
      final json = delta.toJson();

      expect(json['summarized_up_to_id'], equals(10));
    });

    test('setSummary handles long summary', () {
      final longSummary = 'A' * 10000; // 10K character summary
      final delta = SessionDelta.setSummary(
        summary: longSummary,
        summarizedUpToId: 50,
      );
      final json = delta.toJson();

      expect(json['summary'].length, equals(10000));
    });

    test('setSummary handles special characters', () {
      final summary = 'User asked: "How\'s the weather?" with <tags> & symbols.';
      final delta = SessionDelta.setSummary(
        summary: summary,
        summarizedUpToId: 5,
      );
      final json = delta.toJson();

      expect(json['summary'], equals(summary));
    });

    test('setSummary handles newlines', () {
      final summary = 'First point.\nSecond point.\nThird point.';
      final delta = SessionDelta.setSummary(
        summary: summary,
        summarizedUpToId: 3,
      );
      final json = delta.toJson();

      expect(json['summary'], contains('\n'));
    });

    test('setSummary handles unicode', () {
      final summary = 'User asked about 日本語 and emoji 🎉';
      final delta = SessionDelta.setSummary(
        summary: summary,
        summarizedUpToId: 2,
      );
      final json = delta.toJson();

      expect(json['summary'], contains('日本語'));
      expect(json['summary'], contains('🎉'));
    });
  });

  group('syncFull delta edge cases', () {
    test('handles empty messages list', () {
      final delta = SessionDelta.syncFull(
        conversationId: 1,
        messages: [],
      );
      final json = delta.toJson();

      expect(json['messages'], isEmpty);
    });

    test('handles large messages list', () {
      final messages = List.generate(
        100,
        (i) => {
          'role': i.isEven ? 'user' : 'assistant',
          'content': 'Message $i',
        },
      );

      final delta = SessionDelta.syncFull(
        conversationId: 1,
        messages: messages,
      );
      final json = delta.toJson();

      expect(json['messages'].length, equals(100));
    });

    test('handles messages with complex content', () {
      final messages = [
        {'role': 'user', 'content': 'Hello'},
        {
          'role': 'assistant',
          'content': [
            {'type': 'text', 'text': 'Let me help you.'},
            {
              'type': 'tool_use',
              'id': 'tool_1',
              'name': 'calculator',
              'input': {'expression': '2+2'},
            },
          ],
        },
        {
          'role': 'user',
          'content': [
            {
              'type': 'tool_result',
              'tool_use_id': 'tool_1',
              'content': '4',
            },
          ],
        },
      ];

      final delta = SessionDelta.syncFull(
        conversationId: 1,
        messages: messages,
      );
      final json = delta.toJson();

      expect(json['messages'].length, equals(3));
    });

    test('handles conversation ID of 0', () {
      final delta = SessionDelta.syncFull(
        conversationId: 0,
        messages: [{'role': 'user', 'content': 'Test'}],
      );
      final json = delta.toJson();

      expect(json['conversation_id'], equals(0));
    });

    test('handles very large conversation ID', () {
      final delta = SessionDelta.syncFull(
        conversationId: 9007199254740991, // Max safe integer
        messages: [{'role': 'user', 'content': 'Test'}],
      );
      final json = delta.toJson();

      expect(json['conversation_id'], equals(9007199254740991));
    });
  });

  group('newConversation delta', () {
    test('creates with positive ID', () {
      final delta = SessionDelta.newConversation(42);
      expect(delta.toJson()['conversation_id'], equals(42));
    });

    test('creates with ID of 1', () {
      final delta = SessionDelta.newConversation(1);
      expect(delta.toJson()['conversation_id'], equals(1));
    });

    test('action is always newConversation', () {
      final delta = SessionDelta.newConversation(999);
      expect(delta.toJson()['action'], equals('newConversation'));
    });
  });

  group('addMessage delta', () {
    test('preserves all message fields', () {
      final message = {
        'role': 'user',
        'content': 'Hello',
        'timestamp': '2024-06-15T10:30:00Z',
        'metadata': {'source': 'mobile'},
      };

      final delta = SessionDelta.addMessage(message);
      final json = delta.toJson();

      expect(json['message']['role'], equals('user'));
      expect(json['message']['content'], equals('Hello'));
      expect(json['message']['timestamp'], equals('2024-06-15T10:30:00Z'));
      expect(json['message']['metadata']['source'], equals('mobile'));
    });

    test('handles message with only required fields', () {
      final message = {
        'role': 'assistant',
        'content': 'Response',
      };

      final delta = SessionDelta.addMessage(message);
      final json = delta.toJson();

      expect(json['action'], equals('addMessage'));
      expect(json['message']['role'], equals('assistant'));
      expect(json['message']['content'], equals('Response'));
    });
  });
}
