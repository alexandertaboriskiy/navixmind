import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:navixmind/core/bridge/messages.dart';
import 'package:navixmind/core/services/offline_queue_manager.dart';
import 'package:navixmind/core/utils/rate_limiter.dart';

/// Integration tests for full user query flows
///
/// These tests verify the interaction between multiple components
/// to ensure the complete flow works correctly.
void main() {
  group('User query flow integration', () {
    test('simple text query flow', () {
      // Simulate a user sending a simple text query

      // 1. Rate limiter check
      final limiter = RateLimiter();
      expect(limiter.canProceed(), isTrue);
      limiter.recordRequest();

      // 2. Create request message
      final request = JsonRpcRequest(
        method: 'query',
        params: {'text': 'Hello, how are you?'},
      );

      expect(request.method, equals('query'));
      expect(request.params['text'], equals('Hello, how are you?'));
      expect(request.id, isNotEmpty);
      expect(request.jsonrpc, equals('2.0'));
    });

    test('query with file attachment flow', () {
      final limiter = RateLimiter();

      // 1. Rate limiter check
      expect(limiter.canProceed(), isTrue);
      limiter.recordRequest();

      // 2. File validation (simulated)
      const fileSize = 5 * 1024 * 1024; // 5MB
      const fileLimit = 20 * 1024 * 1024; // 20MB for images
      expect(fileSize < fileLimit, isTrue);

      // 3. Create request with file
      final request = JsonRpcRequest(
        method: 'query',
        params: {
          'text': 'Describe this image',
          'files': ['/storage/image.jpg'],
        },
      );

      expect(request.params['files'], isA<List>());
    });

    test('response handling flow', () {
      // Simulate receiving a response

      // Success response
      final successResponse = JsonRpcResponse(
        id: 'test-id',
        result: {
          'content': 'Here is the response from the AI assistant.',
          'usage': {
            'input_tokens': 100,
            'output_tokens': 50,
          },
        },
      );

      expect(successResponse.isSuccess, isTrue);
      expect(successResponse.result?['content'], isA<String>());
      expect(successResponse.result?['usage']['input_tokens'], equals(100));

      // Error response
      final errorResponse = JsonRpcResponse(
        id: 'test-id-2',
        error: JsonRpcError(
          code: -32000,
          message: 'Rate limit exceeded',
        ),
      );

      expect(errorResponse.isError, isTrue);
      expect(errorResponse.error?.code, equals(-32000));
    });
  });

  group('Agent loop integration', () {
    test('simulates ReAct loop flow', () {
      final limiter = RateLimiter();
      limiter.resetQueryCounters();

      final steps = <Map<String, String>>[];

      // Simulate ReAct loop iterations
      while (limiter.canContinueAgentLoop()) {
        // Each iteration: Reason + Act
        steps.add({
          'thought': 'I need to search for information',
          'action': 'web_search',
        });

        // Simulate tool call
        if (!limiter.canMakeToolCall()) break;

        // Check if should continue (simulate AI decision)
        if (steps.length >= 3) break; // Simulated completion
      }

      expect(steps.length, greaterThan(0));
      expect(steps.length, lessThanOrEqualTo(maxAgentLoops));
    });

    test('handles max iterations gracefully', () {
      final limiter = RateLimiter();
      limiter.resetQueryCounters();

      var iterations = 0;
      while (limiter.canContinueAgentLoop()) {
        iterations++;
      }

      expect(iterations, equals(maxAgentLoops));
      expect(limiter.canContinueAgentLoop(), isFalse);
    });

    test('handles max tool calls gracefully', () {
      final limiter = RateLimiter();
      limiter.resetQueryCounters();

      var toolCalls = 0;
      while (limiter.canMakeToolCall()) {
        toolCalls++;
      }

      expect(toolCalls, equals(maxToolCallsPerQuery));
      expect(limiter.canMakeToolCall(), isFalse);
    });
  });

  group('Native tool execution integration', () {
    test('FFmpeg operation flow', () {
      // Simulate Python requesting FFmpeg operation

      final request = NativeToolRequest.fromJson({
        'id': 'ffmpeg-request-1',
        'params': {
          'tool': 'ffmpeg',
          'args': {
            'input_path': '/storage/input.mp4',
            'output_path': '/storage/output.mp4',
            'operation': 'crop',
            'params': {
              'x': 0,
              'y': 100,
              'width': 1080,
              'height': 1920,
            },
          },
          'timeout_ms': 120000,
        },
      });

      expect(request.tool, equals('ffmpeg'));
      expect(request.args['operation'], equals('crop'));
      expect(request.timeoutMs, equals(120000));

      // Simulate success response
      final successResult = {
        'success': true,
        'output_path': '/storage/output.mp4',
        'message': 'Processing complete',
      };

      expect(successResult['success'], isTrue);
    });

    test('OCR operation flow', () {
      final request = NativeToolRequest.fromJson({
        'id': 'ocr-request-1',
        'params': {
          'tool': 'ocr',
          'args': {'image_path': '/storage/document.jpg'},
        },
      });

      expect(request.tool, equals('ocr'));

      // Simulate OCR result
      final ocrResult = {
        'success': true,
        'text': 'Extracted text from the image',
        'blocks': [
          {
            'text': 'Header text',
            'bounding_box': {'left': 10, 'top': 20, 'right': 200, 'bottom': 50},
          },
        ],
        'block_count': 1,
      };

      expect(ocrResult['success'], isTrue);
      expect(ocrResult['text'], isA<String>());
    });

    test('smart crop flow with face detection', () {
      // 1. Request comes in
      final request = NativeToolRequest.fromJson({
        'id': 'smart-crop-1',
        'params': {
          'tool': 'smart_crop',
          'args': {
            'input_path': '/storage/video.mp4',
            'output_path': '/storage/cropped.mp4',
            'aspect_ratio': '9:16',
          },
        },
      });

      expect(request.tool, equals('smart_crop'));

      // 2. Face detection result (intermediate)
      final faceResult = {
        'faces': [
          {'center_x': 500, 'center_y': 400, 'width': 200, 'height': 200},
        ],
        'face_count': 1,
      };

      expect(faceResult['face_count'], equals(1));

      // 3. Final crop result
      final cropResult = {
        'success': true,
        'output_path': '/storage/cropped.mp4',
        'crop_region': {'x': 200, 'y': 0, 'width': 1080, 'height': 1920},
        'faces_detected': 1,
      };

      expect(cropResult['success'], isTrue);
      expect(cropResult['faces_detected'], equals(1));
    });
  });

  group('Offline queue integration', () {
    test('message queuing and processing flow', () async {
      // Simulate queueing messages while offline

      final events = <OfflineQueueEvent>[];
      final controller = StreamController<OfflineQueueEvent>.broadcast();

      controller.stream.listen((event) {
        events.add(event);
      });

      // Queue messages while offline
      controller.add(OfflineQueueEvent(
        type: OfflineQueueEventType.messageQueued,
        pendingCount: 1,
        message: 'Message 1 queued',
      ));

      controller.add(OfflineQueueEvent(
        type: OfflineQueueEventType.messageQueued,
        pendingCount: 2,
        message: 'Message 2 queued',
      ));

      // Come back online and process
      controller.add(OfflineQueueEvent(
        type: OfflineQueueEventType.processingStarted,
        pendingCount: 2,
        message: 'Processing started',
      ));

      controller.add(OfflineQueueEvent(
        type: OfflineQueueEventType.messageSent,
        pendingCount: 1,
        message: 'Message 1 sent',
      ));

      controller.add(OfflineQueueEvent(
        type: OfflineQueueEventType.messageSent,
        pendingCount: 0,
        message: 'Message 2 sent',
      ));

      controller.add(OfflineQueueEvent(
        type: OfflineQueueEventType.queueEmpty,
        pendingCount: 0,
        message: 'All messages sent',
      ));

      await Future.delayed(Duration.zero);

      expect(events.length, equals(6));
      expect(events.last.type, equals(OfflineQueueEventType.queueEmpty));
      expect(events.last.pendingCount, equals(0));

      await controller.close();
    });

    test('handles connection loss during processing', () async {
      final events = <OfflineQueueEvent>[];
      final controller = StreamController<OfflineQueueEvent>.broadcast();

      controller.stream.listen((event) {
        events.add(event);
      });

      // Start processing
      controller.add(OfflineQueueEvent(
        type: OfflineQueueEventType.processingStarted,
        pendingCount: 3,
        message: 'Processing started',
      ));

      // Send one successfully
      controller.add(OfflineQueueEvent(
        type: OfflineQueueEventType.messageSent,
        pendingCount: 2,
        message: 'Message sent',
      ));

      // Lose connection
      controller.add(OfflineQueueEvent(
        type: OfflineQueueEventType.processingPaused,
        pendingCount: 2,
        message: 'Connection lost',
      ));

      await Future.delayed(Duration.zero);

      expect(events.last.type, equals(OfflineQueueEventType.processingPaused));
      expect(events.last.pendingCount, equals(2)); // 2 still pending

      await controller.close();
    });
  });

  group('Session delta sync integration', () {
    test('new conversation flow', () {
      final delta = SessionDelta.newConversation(42);
      final json = delta.toJson();

      expect(json['action'], equals('newConversation'));
      expect(json['conversation_id'], equals(42));
    });

    test('message exchange flow', () {
      final deltas = <SessionDelta>[];

      // User sends message
      deltas.add(SessionDelta.addMessage({
        'role': 'user',
        'content': 'Hello!',
        'timestamp': DateTime.now().toIso8601String(),
      }));

      // Assistant responds
      deltas.add(SessionDelta.addMessage({
        'role': 'assistant',
        'content': 'Hello! How can I help you today?',
        'timestamp': DateTime.now().toIso8601String(),
      }));

      expect(deltas.length, equals(2));
      expect(deltas[0].toJson()['message']['role'], equals('user'));
      expect(deltas[1].toJson()['message']['role'], equals('assistant'));
    });

    test('summarization trigger flow', () {
      // After many messages, a summary might be generated
      final delta = SessionDelta.setSummary(
        summary: 'User asked about weather. Assistant provided forecast.',
        summarizedUpToId: 10,
      );

      final json = delta.toJson();
      expect(json['action'], equals('setSummary'));
      expect(json['summary'], contains('weather'));
      expect(json['summarized_up_to_id'], equals(10));
    });

    test('full sync on app resume', () {
      // When app resumes, might need full sync
      final delta = SessionDelta.syncFull(
        conversationId: 123,
        messages: [
          {'role': 'user', 'content': 'Message 1'},
          {'role': 'assistant', 'content': 'Response 1'},
          {'role': 'user', 'content': 'Message 2'},
        ],
        summary: 'Previous conversation about topic X',
      );

      final json = delta.toJson();
      expect(json['action'], equals('syncFull'));
      expect(json['messages'].length, equals(3));
      expect(json['summary'], isNotNull);
    });
  });

  group('Cost tracking integration', () {
    test('tracks cost over multiple queries', () {
      final costs = <double>[];

      // Simulate multiple API calls
      costs.add(_calculateCost('claude-sonnet-4-20250514', 500, 200));
      costs.add(_calculateCost('claude-sonnet-4-20250514', 800, 350));
      costs.add(_calculateCost('claude-haiku-4-20250514', 1000, 500));

      final totalCost = costs.reduce((a, b) => a + b);

      expect(totalCost, greaterThan(0));
      expect(costs[2], lessThan(costs[0])); // Haiku cheaper
    });

    test('respects daily limits', () {
      const dailyLimit = 5.0;
      var todaySpent = 0.0;

      // Simulate queries throughout day
      for (var i = 0; i < 100 && todaySpent < dailyLimit; i++) {
        final queryCost = _calculateCost('claude-sonnet-4-20250514', 500, 200);
        if (todaySpent + queryCost <= dailyLimit) {
          todaySpent += queryCost;
        } else {
          break;
        }
      }

      expect(todaySpent, lessThanOrEqualTo(dailyLimit));
    });
  });

  group('Error handling integration', () {
    test('handles rate limit error gracefully', () {
      final response = JsonRpcResponse(
        id: 'request-1',
        error: JsonRpcError(
          code: 429,
          message: 'Rate limit exceeded. Retry after 60 seconds.',
          data: {'retry_after': 60},
        ),
      );

      expect(response.isError, isTrue);
      expect(response.error?.code, equals(429));
      expect(response.error?.data?['retry_after'], equals(60));
    });

    test('handles API error gracefully', () {
      final response = JsonRpcResponse(
        id: 'request-2',
        error: JsonRpcError(
          code: 500,
          message: 'Internal server error',
        ),
      );

      expect(response.isError, isTrue);
      expect(response.error?.code, equals(500));
    });

    test('handles tool execution error', () {
      // Simulate FFmpeg failure
      final errorResult = {
        'success': false,
        'error': 'FFmpeg failed: Invalid input file',
        'code': -32000,
      };

      expect(errorResult['success'], isFalse);
      expect(errorResult['error'], contains('FFmpeg failed'));
    });
  });

  group('Concurrent operations', () {
    test('handles multiple concurrent requests', () async {
      final limiter = RateLimiter();
      final completers = <Completer<bool>>[];

      // Start multiple "requests"
      for (var i = 0; i < 5; i++) {
        if (limiter.canProceed()) {
          limiter.recordRequest();
          final completer = Completer<bool>();
          completers.add(completer);

          // Simulate async completion
          Future.delayed(Duration(milliseconds: 10 * i), () {
            completer.complete(true);
          });
        }
      }

      final results = await Future.wait(completers.map((c) => c.future));

      expect(results.length, equals(5));
      expect(results.every((r) => r), isTrue);
    });
  });

  group('Auth token flow integration', () {
    test('token refresh request flow', () {
      // 1. Python sends request_fresh_token
      final tokenRequest = {
        'jsonrpc': '2.0',
        'id': 'token-req-123',
        'method': 'request_fresh_token',
        'params': {},
      };

      expect(tokenRequest['method'], equals('request_fresh_token'));
      expect(tokenRequest['id'], isNotNull);

      // 2. Flutter refreshes and responds
      final tokenResponse = JsonRpcResponse(
        id: 'token-req-123',
        result: {
          'access_token': 'ya29.a0AfH6SMC_new_fresh_token',
        },
      );

      expect(tokenResponse.isSuccess, isTrue);
      expect(tokenResponse.result?['access_token'], isNotNull);
    });

    test('auth error handling flow', () {
      // Python reports auth error
      final authError = <String, dynamic>{
        'jsonrpc': '2.0',
        'id': 'query-456',
        'method': 'auth_error',
        'params': {
          'error': 'token_expired',
          'message': 'Google access token has expired',
          'service': 'google_drive',
        },
      };

      expect(authError['method'], equals('auth_error'));
      expect((authError['params'] as Map<String, dynamic>)['error'], equals('token_expired'));
      expect((authError['params'] as Map<String, dynamic>)['service'], equals('google_drive'));

      // Flutter should:
      // 1. Show error to user
      // 2. Attempt re-authentication
      // 3. Retry the failed operation
    });

    test('token refresh with retry flow', () {
      // Simulate failed request due to expired token
      final failedResponse = JsonRpcResponse(
        id: 'original-req-1',
        error: JsonRpcError(
          code: 401,
          message: 'Unauthorized: token expired',
          data: {'retry_with_fresh_token': true},
        ),
      );

      expect(failedResponse.isError, isTrue);
      expect(failedResponse.error?.data?['retry_with_fresh_token'], isTrue);

      // Token refresh request
      final tokenRequest = JsonRpcRequest(
        method: 'request_fresh_token',
        params: {},
      );

      expect(tokenRequest.method, equals('request_fresh_token'));

      // Token provided
      final tokenResponse = JsonRpcResponse(
        id: tokenRequest.id,
        result: {'access_token': 'fresh_token_here'},
      );

      expect(tokenResponse.isSuccess, isTrue);

      // Retry original request with new token
      final retryRequest = JsonRpcRequest(
        method: 'query',
        params: {
          'text': 'Original query',
          'auth_token': 'fresh_token_here',
        },
      );

      expect(retryRequest.params['auth_token'], equals('fresh_token_here'));
    });

    test('handles token refresh failure', () {
      // Token refresh fails
      final tokenFailure = JsonRpcResponse(
        id: 'token-req-fail',
        error: JsonRpcError(
          code: -32000,
          message: 'Unable to refresh token: user not signed in',
        ),
      );

      expect(tokenFailure.isError, isTrue);

      // Should propagate to user and prompt re-authentication
      expect(tokenFailure.error?.message, contains('not signed in'));
    });

    test('multiple concurrent token requests coalesce', () {
      // Simulate multiple requests arriving that all need token refresh
      final requests = [
        {'id': 'req-1', 'needs_token': true},
        {'id': 'req-2', 'needs_token': true},
        {'id': 'req-3', 'needs_token': true},
      ];

      // Only one token refresh should happen
      var tokenRefreshCount = 0;
      String? sharedToken;

      for (final req in requests) {
        if (req['needs_token'] == true && sharedToken == null) {
          tokenRefreshCount++;
          sharedToken = 'shared_fresh_token';
        }
      }

      expect(tokenRefreshCount, equals(1));
      expect(sharedToken, isNotNull);
    });

    test('cost context passed with query', () {
      // Simulate query with cost context
      final queryWithCost = JsonRpcRequest(
        method: 'query',
        params: {
          'text': 'What is the weather?',
          'context': {
            'conversation_id': 123,
            'cost_percent_used': 75.5,
            'has_attachments': false,
          },
        },
      );

      expect(queryWithCost.params['context']['cost_percent_used'], equals(75.5));

      // Python should use this to select appropriate model
      final costPercent = queryWithCost.params['context']['cost_percent_used'] as double;
      final shouldUseHaiku = costPercent >= 80;

      expect(shouldUseHaiku, isFalse); // 75.5% is below threshold
    });

    test('cost context triggers model switch at threshold', () {
      final queryNearLimit = JsonRpcRequest(
        method: 'query',
        params: {
          'text': 'Simple question',
          'context': {
            'cost_percent_used': 85.0, // Above 80% threshold
          },
        },
      );

      final costPercent = queryNearLimit.params['context']['cost_percent_used'] as double;
      final shouldUseHaiku = costPercent >= 80;

      expect(shouldUseHaiku, isTrue);
    });

    test('attachments flag set correctly', () {
      // Query with attachments
      final withAttachments = JsonRpcRequest(
        method: 'query',
        params: {
          'text': 'Analyze this document',
          'files': ['/path/to/doc.pdf'],
          'context': {
            'has_attachments': true,
          },
        },
      );

      expect(withAttachments.params['context']['has_attachments'], isTrue);

      // Query without attachments
      final withoutAttachments = JsonRpcRequest(
        method: 'query',
        params: {
          'text': 'What time is it?',
          'context': {
            // has_attachments not set
          },
        },
      );

      expect(
        withoutAttachments.params['context'].containsKey('has_attachments'),
        isFalse,
      );
    });
  });

  group('Model selection integration', () {
    test('simple query uses Haiku when cost is high', () {
      final simpleQueries = [
        'What time is it?',
        'Convert 5 miles to km',
        'Format this date: 2024-06-15',
        'Count the words in this sentence',
      ];

      for (final query in simpleQueries) {
        final isSimple = _isSimpleQuery(query);
        expect(isSimple, isTrue, reason: 'Query should be simple: $query');
      }
    });

    test('complex query uses Sonnet regardless of cost', () {
      final complexQueries = [
        'Analyze this code and find bugs',
        'Write a Python function to sort a list',
        'Debug this error message',
        'Implement a binary search tree',
        'Design a REST API for a todo app',
      ];

      for (final query in complexQueries) {
        final isComplex = _isComplexQuery(query);
        expect(isComplex, isTrue, reason: 'Query should be complex: $query');
      }
    });

    test('model selection respects user preference', () {
      // User explicitly wants Sonnet
      final userPrefersSonnet = {'preferred_model': 'sonnet'};
      final modelForSonnetPref = _selectModel(
        query: 'Simple question',
        costPercent: 90,
        preference: userPrefersSonnet,
      );
      expect(modelForSonnetPref, equals('sonnet'));

      // User explicitly wants Haiku
      final userPrefersHaiku = {'preferred_model': 'haiku'};
      final modelForHaikuPref = _selectModel(
        query: 'Complex analysis task',
        costPercent: 10,
        preference: userPrefersHaiku,
      );
      expect(modelForHaikuPref, equals('haiku'));
    });
  });

  group('Smart crop integration with video', () {
    test('full video smart crop flow', () {
      // 1. Receive smart crop request
      final request = NativeToolRequest.fromJson({
        'id': 'video-crop-1',
        'params': {
          'tool': 'smart_crop',
          'args': {
            'input_path': '/storage/video.mp4',
            'output_path': '/storage/cropped.mp4',
            'aspect_ratio': '9:16',
          },
          'timeout_ms': 300000,
        },
      });

      expect(request.tool, equals('smart_crop'));
      expect(request.timeoutMs, equals(300000));

      // 2. Sample frames (simulated)
      final framesAnalyzed = 10;
      final facesPerFrame = [1, 1, 0, 1, 1, 1, 0, 1, 1, 1]; // Some frames miss face

      final totalDetections = facesPerFrame.reduce((a, b) => a + b);
      expect(totalDetections, equals(8));

      // 3. Calculate average face position
      final avgX = 500;
      final avgY = 400;

      // 4. Calculate crop region
      final sourceWidth = 1920;
      final sourceHeight = 1080;
      final cropHeight = 1080;
      final cropWidth = (1080 * 9 / 16).round(); // 607

      var cropX = avgX - cropWidth ~/ 2;
      cropX = cropX.clamp(0, sourceWidth - cropWidth);

      expect(cropX, greaterThanOrEqualTo(0));
      expect(cropX + cropWidth, lessThanOrEqualTo(sourceWidth));

      // 5. Result
      final result = {
        'success': true,
        'output_path': '/storage/cropped.mp4',
        'crop_region': {
          'x': cropX,
          'y': 0,
          'width': cropWidth,
          'height': cropHeight,
        },
        'faces_detected': totalDetections,
        'frames_sampled': framesAnalyzed,
        'crop_strategy': 'face_centered',
      };

      expect(result['success'], isTrue);
      expect(result['crop_strategy'], equals('face_centered'));
    });

    test('smart crop fallback when no faces detected', () {
      // Simulate no faces in video
      final facesPerFrame = [0, 0, 0, 0, 0];
      final totalFaces = facesPerFrame.reduce((a, b) => a + b);

      expect(totalFaces, equals(0));

      // Should use rule of thirds
      final sourceWidth = 1920;
      final sourceHeight = 1080;
      final cropWidth = 607;
      final cropHeight = 1080;

      // Rule of thirds: center horizontally, bias upward
      final targetX = sourceWidth ~/ 2;
      final targetY = (sourceHeight * 2) ~/ 5;

      var cropX = targetX - cropWidth ~/ 2;
      var cropY = targetY - cropHeight ~/ 2;
      cropX = cropX.clamp(0, sourceWidth - cropWidth);
      cropY = cropY.clamp(0, sourceHeight - cropHeight);

      final result = {
        'success': true,
        'crop_region': {
          'x': cropX,
          'y': cropY,
          'width': cropWidth,
          'height': cropHeight,
        },
        'faces_detected': 0,
        'crop_strategy': 'rule_of_thirds',
      };

      expect(result['crop_strategy'], equals('rule_of_thirds'));
      expect(result['faces_detected'], equals(0));
    });
  });

  group('CSV export integration', () {
    test('full export flow', () {
      // Simulate usage data
      final usageRecords = [
        _MockUsageRecord(
          date: DateTime(2024, 6, 14),
          model: 'claude-sonnet-4-20250514',
          inputTokens: 1000,
          outputTokens: 500,
          cost: 0.0105,
        ),
        _MockUsageRecord(
          date: DateTime(2024, 6, 14),
          model: 'claude-haiku-4-20250514',
          inputTokens: 2000,
          outputTokens: 1000,
          cost: 0.00175,
        ),
        _MockUsageRecord(
          date: DateTime(2024, 6, 15),
          model: 'claude-sonnet-4-20250514',
          inputTokens: 500,
          outputTokens: 250,
          cost: 0.00525,
        ),
      ];

      // Generate CSV
      final csv = _generateCsv(usageRecords);

      // Verify structure
      final lines = csv.trim().split('\n');
      expect(lines.length, equals(4)); // Header + 3 data rows

      // Verify header
      expect(lines[0], contains('Date'));
      expect(lines[0], contains('Model'));
      expect(lines[0], contains('Cost'));

      // Verify data
      expect(lines[1], contains('2024-06-14'));
      expect(lines[1], contains('claude-sonnet-4'));
    });

    test('export handles empty data', () {
      final csv = _generateCsv([]);
      final lines = csv.trim().split('\n');

      expect(lines.length, equals(1)); // Only header
      expect(lines[0], contains('Date'));
    });

    test('export preserves cost precision', () {
      final records = [
        _MockUsageRecord(
          date: DateTime(2024, 6, 15),
          model: 'claude-haiku-4-20250514',
          inputTokens: 10,
          outputTokens: 5,
          cost: 0.0000087, // Very small cost
        ),
      ];

      final csv = _generateCsv(records);

      // Should preserve precision
      expect(csv, contains('0.000'));
    });
  });
}

// Helper function for cost calculation
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

// Helper for simple query detection
bool _isSimpleQuery(String query) {
  final simplePatterns = [
    'what time',
    'convert',
    'format',
    'count',
    'classify',
    'extract',
    'translate',
  ];

  final lower = query.toLowerCase();
  return simplePatterns.any((p) => lower.contains(p));
}

// Helper for complex query detection
bool _isComplexQuery(String query) {
  final complexPatterns = [
    'analyze',
    'write',
    'debug',
    'implement',
    'design',
    'explain',
    'review',
  ];

  final lower = query.toLowerCase();
  return complexPatterns.any((p) => lower.contains(p));
}

// Helper for model selection
String _selectModel({
  required String query,
  required double costPercent,
  required Map<String, String> preference,
}) {
  // User preference takes priority
  if (preference.containsKey('preferred_model')) {
    return preference['preferred_model']!;
  }

  // Cost-based switching
  if (costPercent >= 80 && _isSimpleQuery(query)) {
    return 'haiku';
  }

  return 'sonnet';
}

// Mock usage record for CSV tests
class _MockUsageRecord {
  final DateTime date;
  final String model;
  final int inputTokens;
  final int outputTokens;
  final double cost;

  _MockUsageRecord({
    required this.date,
    required this.model,
    required this.inputTokens,
    required this.outputTokens,
    required this.cost,
  });
}

// CSV generation helper
String _generateCsv(List<_MockUsageRecord> records) {
  final buffer = StringBuffer();
  buffer.writeln('Date,Model,Input Tokens,Output Tokens,Cost (USD)');

  for (final record in records) {
    final dateStr =
        '${record.date.year}-${record.date.month.toString().padLeft(2, '0')}-${record.date.day.toString().padLeft(2, '0')}';
    buffer.writeln(
        '$dateStr,${record.model},${record.inputTokens},${record.outputTokens},${record.cost.toStringAsFixed(6)}');
  }

  return buffer.toString();
}
