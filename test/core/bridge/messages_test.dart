import 'package:flutter_test/flutter_test.dart';
import 'package:navixmind/core/bridge/messages.dart';

void main() {
  group('JsonRpcRequest', () {
    test('creates with required fields', () {
      final request = JsonRpcRequest(
        method: 'query',
        params: {'text': 'Hello'},
      );

      expect(request.jsonrpc, equals('2.0'));
      expect(request.method, equals('query'));
      expect(request.params['text'], equals('Hello'));
      expect(request.id, isNotEmpty);
    });

    test('creates with custom id', () {
      final request = JsonRpcRequest(
        method: 'test',
        params: {},
        id: 'custom-id-123',
      );

      expect(request.id, equals('custom-id-123'));
    });

    test('generates unique ids for different requests', () {
      final request1 = JsonRpcRequest(method: 'test', params: {});
      final request2 = JsonRpcRequest(method: 'test', params: {});

      expect(request1.id, isNot(equals(request2.id)));
    });

    test('toJson returns correct structure', () {
      final request = JsonRpcRequest(
        method: 'query',
        params: {'text': 'Hello', 'files': ['/path/to/file']},
        id: 'test-id',
      );

      final json = request.toJson();

      expect(json['jsonrpc'], equals('2.0'));
      expect(json['id'], equals('test-id'));
      expect(json['method'], equals('query'));
      expect(json['params']['text'], equals('Hello'));
      expect((json['params']['files'] as List).first, equals('/path/to/file'));
    });

    test('fromJson parses correctly', () {
      final json = {
        'jsonrpc': '2.0',
        'id': 'parsed-id',
        'method': 'parsed_method',
        'params': {'key': 'value'},
      };

      final request = JsonRpcRequest.fromJson(json);

      expect(request.id, equals('parsed-id'));
      expect(request.method, equals('parsed_method'));
      expect(request.params['key'], equals('value'));
    });

    test('fromJson handles missing params', () {
      final json = {
        'jsonrpc': '2.0',
        'id': 'test',
        'method': 'test',
      };

      final request = JsonRpcRequest.fromJson(json);
      expect(request.params, isEmpty);
    });
  });

  group('JsonRpcResponse', () {
    test('creates success response', () {
      final response = JsonRpcResponse(
        id: 'test-id',
        result: {'content': 'Response content'},
      );

      expect(response.jsonrpc, equals('2.0'));
      expect(response.id, equals('test-id'));
      expect(response.result, isNotNull);
      expect(response.error, isNull);
      expect(response.isSuccess, isTrue);
      expect(response.isError, isFalse);
    });

    test('creates error response', () {
      final response = JsonRpcResponse(
        id: 'test-id',
        error: JsonRpcError(code: -32600, message: 'Invalid request'),
      );

      expect(response.id, equals('test-id'));
      expect(response.result, isNull);
      expect(response.error, isNotNull);
      expect(response.isSuccess, isFalse);
      expect(response.isError, isTrue);
    });

    test('toJson includes result for success', () {
      final response = JsonRpcResponse(
        id: 'test-id',
        result: {'data': 'value'},
      );

      final json = response.toJson();

      expect(json['jsonrpc'], equals('2.0'));
      expect(json['id'], equals('test-id'));
      expect(json['result']['data'], equals('value'));
      expect(json.containsKey('error'), isFalse);
    });

    test('toJson includes error for failure', () {
      final response = JsonRpcResponse(
        id: 'test-id',
        error: JsonRpcError(code: -32600, message: 'Error'),
      );

      final json = response.toJson();

      expect(json['jsonrpc'], equals('2.0'));
      expect(json['id'], equals('test-id'));
      expect(json['error']['code'], equals(-32600));
      expect(json.containsKey('result'), isFalse);
    });

    test('fromJson parses success response', () {
      final json = {
        'jsonrpc': '2.0',
        'id': 'parsed-id',
        'result': {'content': 'Parsed content'},
      };

      final response = JsonRpcResponse.fromJson(json);

      expect(response.id, equals('parsed-id'));
      expect(response.result!['content'], equals('Parsed content'));
      expect(response.isSuccess, isTrue);
    });

    test('fromJson parses error response', () {
      final json = {
        'jsonrpc': '2.0',
        'id': 'parsed-id',
        'error': {
          'code': -32601,
          'message': 'Method not found',
        },
      };

      final response = JsonRpcResponse.fromJson(json);

      expect(response.id, equals('parsed-id'));
      expect(response.error!.code, equals(-32601));
      expect(response.error!.message, equals('Method not found'));
      expect(response.isError, isTrue);
    });

    test('handles null id', () {
      final response = JsonRpcResponse(
        result: {'notification': true},
      );

      expect(response.id, isNull);
      final json = response.toJson();
      expect(json.containsKey('id'), isFalse);
    });
  });

  group('JsonRpcError', () {
    test('creates with required fields', () {
      final error = JsonRpcError(
        code: -32600,
        message: 'Invalid Request',
      );

      expect(error.code, equals(-32600));
      expect(error.message, equals('Invalid Request'));
      expect(error.data, isNull);
    });

    test('creates with data', () {
      final error = JsonRpcError(
        code: -32000,
        message: 'Tool error',
        data: {'tool': 'ffmpeg', 'reason': 'File not found'},
      );

      expect(error.data, isNotNull);
      expect(error.data!['tool'], equals('ffmpeg'));
      expect(error.data!['reason'], equals('File not found'));
    });

    test('toJson returns correct structure', () {
      final error = JsonRpcError(
        code: -32602,
        message: 'Invalid params',
        data: {'param': 'missing_field'},
      );

      final json = error.toJson();

      expect(json['code'], equals(-32602));
      expect(json['message'], equals('Invalid params'));
      expect(json['data']['param'], equals('missing_field'));
    });

    test('toJson excludes null data', () {
      final error = JsonRpcError(
        code: -32700,
        message: 'Parse error',
      );

      final json = error.toJson();

      expect(json.containsKey('data'), isFalse);
    });

    test('fromJson parses correctly', () {
      final json = {
        'code': -32603,
        'message': 'Internal error',
        'data': {'stack': 'trace here'},
      };

      final error = JsonRpcError.fromJson(json);

      expect(error.code, equals(-32603));
      expect(error.message, equals('Internal error'));
      expect(error.data!['stack'], equals('trace here'));
    });

    group('standard error codes', () {
      test('parseError is -32700', () {
        expect(JsonRpcError.parseError, equals(-32700));
      });

      test('invalidRequest is -32600', () {
        expect(JsonRpcError.invalidRequest, equals(-32600));
      });

      test('methodNotFound is -32601', () {
        expect(JsonRpcError.methodNotFound, equals(-32601));
      });

      test('invalidParams is -32602', () {
        expect(JsonRpcError.invalidParams, equals(-32602));
      });

      test('internalError is -32603', () {
        expect(JsonRpcError.internalError, equals(-32603));
      });
    });

    group('custom error codes', () {
      test('toolError is -32000', () {
        expect(JsonRpcError.toolError, equals(-32000));
      });

      test('timeoutError is -32001', () {
        expect(JsonRpcError.timeoutError, equals(-32001));
      });

      test('authError is -32002', () {
        expect(JsonRpcError.authError, equals(-32002));
      });

      test('rateLimitError is -32003', () {
        expect(JsonRpcError.rateLimitError, equals(-32003));
      });

      test('fileTooLargeError is -32004', () {
        expect(JsonRpcError.fileTooLargeError, equals(-32004));
      });

      test('policyError is -32005', () {
        expect(JsonRpcError.policyError, equals(-32005));
      });
    });
  });

  group('LogMessage', () {
    test('creates with required fields', () {
      final log = LogMessage(
        level: 'info',
        message: 'Processing started',
      );

      expect(log.level, equals('info'));
      expect(log.message, equals('Processing started'));
      expect(log.progress, isNull);
      expect(log.timestamp, isNotNull);
    });

    test('creates with progress', () {
      final log = LogMessage(
        level: 'info',
        message: 'Processing',
        progress: 0.5,
      );

      expect(log.progress, equals(0.5));
      expect(log.hasProgress, isTrue);
    });

    test('creates with custom timestamp', () {
      final customTime = DateTime(2024, 1, 15, 10, 30);
      final log = LogMessage(
        level: 'info',
        message: 'Test',
        timestamp: customTime,
      );

      expect(log.timestamp, equals(customTime));
    });

    test('fromJson parses correctly', () {
      final json = {
        'level': 'warning',
        'message': 'Low memory',
        'progress': 0.75,
      };

      final log = LogMessage.fromJson(json);

      expect(log.level, equals('warning'));
      expect(log.message, equals('Low memory'));
      expect(log.progress, equals(0.75));
    });

    test('fromJson handles missing level', () {
      final json = {
        'message': 'Test message',
      };

      final log = LogMessage.fromJson(json);
      expect(log.level, equals('info'));
    });

    test('fromJson handles int progress', () {
      final json = {
        'level': 'info',
        'message': 'Test',
        'progress': 1,
      };

      final log = LogMessage.fromJson(json);
      expect(log.progress, equals(1.0));
    });

    test('isError returns true for error level', () {
      final log = LogMessage(level: 'error', message: 'Error occurred');
      expect(log.isError, isTrue);
    });

    test('isError returns false for other levels', () {
      final log = LogMessage(level: 'info', message: 'Info message');
      expect(log.isError, isFalse);
    });

    test('isWarning returns true for warn level', () {
      final log = LogMessage(level: 'warn', message: 'Warning');
      expect(log.isWarning, isTrue);
    });

    test('isWarning returns true for warning level', () {
      final log = LogMessage(level: 'warning', message: 'Warning');
      expect(log.isWarning, isTrue);
    });

    test('hasProgress returns false when null', () {
      final log = LogMessage(level: 'info', message: 'Test');
      expect(log.hasProgress, isFalse);
    });
  });

  group('NativeToolRequest', () {
    test('creates with required fields', () {
      final request = NativeToolRequest(
        id: 'tool-123',
        tool: 'ffmpeg',
        args: {'input': 'video.mp4', 'output': 'audio.mp3'},
      );

      expect(request.id, equals('tool-123'));
      expect(request.tool, equals('ffmpeg'));
      expect(request.args['input'], equals('video.mp4'));
      expect(request.timeoutMs, equals(30000)); // default
    });

    test('creates with custom timeout', () {
      final request = NativeToolRequest(
        id: 'tool-123',
        tool: 'ocr',
        args: {},
        timeoutMs: 60000,
      );

      expect(request.timeoutMs, equals(60000));
    });

    test('fromJson parses correctly', () {
      final json = <String, dynamic>{
        'id': 'request-456',
        'params': <String, dynamic>{
          'tool': 'file_picker',
          'args': <String, dynamic>{'type': 'image'},
          'timeout_ms': 15000,
        },
      };

      final request = NativeToolRequest.fromJson(json);

      expect(request.id, equals('request-456'));
      expect(request.tool, equals('file_picker'));
      expect(request.args['type'], equals('image'));
      expect(request.timeoutMs, equals(15000));
    });

    test('fromJson handles missing args', () {
      final json = <String, dynamic>{
        'id': 'request-789',
        'params': <String, dynamic>{
          'tool': 'test_tool',
        },
      };

      final request = NativeToolRequest.fromJson(json);
      expect(request.args, isEmpty);
    });

    test('fromJson uses default timeout when missing', () {
      final json = <String, dynamic>{
        'id': 'request-000',
        'params': <String, dynamic>{
          'tool': 'test_tool',
          'args': <String, dynamic>{},
        },
      };

      final request = NativeToolRequest.fromJson(json);
      expect(request.timeoutMs, equals(30000));
    });
  });

  group('DeltaAction', () {
    test('has all expected values', () {
      expect(DeltaAction.values, contains(DeltaAction.newConversation));
      expect(DeltaAction.values, contains(DeltaAction.addMessage));
      expect(DeltaAction.values, contains(DeltaAction.setSummary));
      expect(DeltaAction.values, contains(DeltaAction.syncFull));
      expect(DeltaAction.values.length, equals(4));
    });
  });

  group('SessionDelta', () {
    test('creates newConversation delta', () {
      final delta = SessionDelta.newConversation(123);

      expect(delta.action, equals(DeltaAction.newConversation));
      expect(delta.conversationId, equals(123));
    });

    test('creates addMessage delta', () {
      final message = {
        'id': 1,
        'role': 'user',
        'content': 'Hello',
      };
      final delta = SessionDelta.addMessage(message);

      expect(delta.action, equals(DeltaAction.addMessage));
      expect(delta.message, equals(message));
    });

    test('creates setSummary delta', () {
      final delta = SessionDelta.setSummary(
        summary: 'Conversation summary here',
        summarizedUpToId: 50,
      );

      expect(delta.action, equals(DeltaAction.setSummary));
      expect(delta.summary, equals('Conversation summary here'));
      expect(delta.summarizedUpToId, equals(50));
    });

    test('creates syncFull delta without summary', () {
      final messages = [
        {'id': 1, 'role': 'user', 'content': 'Hello'},
        {'id': 2, 'role': 'assistant', 'content': 'Hi there'},
      ];
      final delta = SessionDelta.syncFull(
        conversationId: 456,
        messages: messages,
      );

      expect(delta.action, equals(DeltaAction.syncFull));
      expect(delta.conversationId, equals(456));
      expect(delta.messages!.length, equals(2));
      expect(delta.summary, isNull);
    });

    test('creates syncFull delta with summary', () {
      final delta = SessionDelta.syncFull(
        conversationId: 789,
        messages: [],
        summary: 'Previous context',
      );

      expect(delta.summary, equals('Previous context'));
    });

    group('toJson', () {
      test('serializes newConversation correctly', () {
        final delta = SessionDelta.newConversation(100);
        final json = delta.toJson();

        expect(json['action'], equals('newConversation'));
        expect(json['conversation_id'], equals(100));
        expect(json.containsKey('message'), isFalse);
        expect(json.containsKey('messages'), isFalse);
      });

      test('serializes addMessage correctly', () {
        final message = {'id': 1, 'content': 'Test'};
        final delta = SessionDelta.addMessage(message);
        final json = delta.toJson();

        expect(json['action'], equals('addMessage'));
        expect(json['message'], equals(message));
      });

      test('serializes setSummary correctly', () {
        final delta = SessionDelta.setSummary(
          summary: 'Summary text',
          summarizedUpToId: 25,
        );
        final json = delta.toJson();

        expect(json['action'], equals('setSummary'));
        expect(json['summary'], equals('Summary text'));
        expect(json['summarized_up_to_id'], equals(25));
      });

      test('serializes syncFull correctly', () {
        final delta = SessionDelta.syncFull(
          conversationId: 200,
          messages: [{'id': 1}],
          summary: 'Context',
        );
        final json = delta.toJson();

        expect(json['action'], equals('syncFull'));
        expect(json['conversation_id'], equals(200));
        expect(json['messages'], isNotNull);
        expect(json['summary'], equals('Context'));
      });

      test('excludes null fields', () {
        final delta = SessionDelta.newConversation(1);
        final json = delta.toJson();

        expect(json.containsKey('message'), isFalse);
        expect(json.containsKey('messages'), isFalse);
        expect(json.containsKey('summary'), isFalse);
        expect(json.containsKey('summarized_up_to_id'), isFalse);
      });
    });
  });
}
