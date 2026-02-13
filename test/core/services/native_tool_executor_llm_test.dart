import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navixmind/core/models/model_registry.dart';
import 'package:navixmind/core/services/local_llm_service.dart';

/// Tests for the llm_generate tool dispatch in NativeToolExecutor.
///
/// Since NativeToolExecutor is tightly coupled to PythonBridge (singleton,
/// starts listening on init), these tests verify the LocalLLMService
/// integration that the executor delegates to, rather than calling
/// _executeLLMGenerate directly.
void main() {
  late Directory tempDir;
  late Directory modelsDir;
  late Map<String, String> fakeStorage;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('nte_llm_test_');
    modelsDir = Directory('${tempDir.path}/mlc_models');
    await modelsDir.create(recursive: true);
    fakeStorage = {};
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<LocalLLMService> createService({
    String modelId = 'qwen2.5-coder-0.5b',
    Future<bool> Function(String, String, String)? loadOverride,
    Future<String> Function(String, String?, int)? generateOverride,
    Future<void> Function()? unloadModelOverride,
  }) async {
    final modelDir = Directory(
      '${modelsDir.path}/${ModelRegistry.getModelDirName(modelId)}',
    );
    await modelDir.create(recursive: true);
    await File('${modelDir.path}/model.bin')
        .writeAsBytes(List.filled(1024, 42));
    await File('${modelDir.path}/ndarray-cache.json').writeAsString('{}');

    final service = LocalLLMService.forTesting(
      modelsDir: modelsDir,
      getPersistedStates: () async => fakeStorage['s'],
      setPersistedStates: (json) async => fakeStorage['s'] = json,
      loadModelOverride: loadOverride,
      generateOverride: generateOverride,
      unloadModelOverride: unloadModelOverride,
    );
    await service.initialize();
    return service;
  }

  group('llm_generate equivalent flow', () {
    test('auto-load and generate succeeds', () async {
      final mockResponse = jsonEncode({
        'stop_reason': 'end_turn',
        'content': [
          {'type': 'text', 'text': 'Hello from local model!'}
        ],
        'usage': {'input_tokens': 5, 'output_tokens': 10},
      });

      final service = await createService(
        loadOverride: (_, __, ___) async => true,
        generateOverride: (_, __, ___) async => mockResponse,
      );

      // Simulate what NativeToolExecutor does: load then generate
      await service.loadModel('qwen2.5-coder-0.5b');
      final result = await service.generate(
        '[{"role":"user","content":"Hi"}]',
        maxTokens: 1024,
      );

      final parsed = jsonDecode(result);
      expect(parsed['content'][0]['text'], 'Hello from local model!');
      service.dispose();
    });

    test('auto-load different model unloads previous', () async {
      final loadLog = <String>[];
      bool unloadCalled = false;

      final service = await createService(
        loadOverride: (modelId, _, __) async {
          loadLog.add(modelId);
          return true;
        },
        unloadModelOverride: () async {
          unloadCalled = true;
        },
        generateOverride: (_, __, ___) async =>
            '{"stop_reason":"end_turn","content":[],"usage":{}}',
      );

      // Also create 1.5b model
      final dir15b = Directory(
        '${modelsDir.path}/${ModelRegistry.getModelDirName('qwen2.5-coder-1.5b')}',
      );
      await dir15b.create(recursive: true);
      await File('${dir15b.path}/model.bin').writeAsBytes(List.filled(1024, 0));
      await File('${dir15b.path}/ndarray-cache.json').writeAsString('{}');

      await service.loadModel('qwen2.5-coder-0.5b');
      await service.loadModel('qwen2.5-coder-1.5b');

      expect(unloadCalled, isTrue);
      expect(loadLog, ['qwen2.5-coder-0.5b', 'qwen2.5-coder-1.5b']);
      service.dispose();
    });

    test('generate without load throws StateError', () async {
      final service = await createService();

      expect(
        () => service.generate('[{"role":"user","content":"Hi"}]'),
        throwsA(isA<StateError>()),
      );
      service.dispose();
    });

    test('tool_use response is returned correctly', () async {
      final toolResponse = jsonEncode({
        'stop_reason': 'tool_use',
        'content': [
          {'type': 'text', 'text': 'Computing...'},
          {
            'type': 'tool_use',
            'id': 'call_abc',
            'name': 'python_execute',
            'input': {'code': 'print(42)'}
          },
        ],
        'usage': {'input_tokens': 15, 'output_tokens': 25},
      });

      final service = await createService(
        loadOverride: (_, __, ___) async => true,
        generateOverride: (_, __, ___) async => toolResponse,
      );

      await service.loadModel('qwen2.5-coder-0.5b');
      final result = await service.generate(
        '[{"role":"user","content":"calculate 42"}]',
        toolsJson: '[{"type":"function","function":{"name":"python_execute"}}]',
      );

      final parsed = jsonDecode(result);
      expect(parsed['stop_reason'], 'tool_use');
      expect(parsed['content'][1]['type'], 'tool_use');
      expect(parsed['content'][1]['name'], 'python_execute');
      service.dispose();
    });

    test('generate failure preserves loaded state', () async {
      int callCount = 0;
      final service = await createService(
        loadOverride: (_, __, ___) async => true,
        generateOverride: (_, __, ___) async {
          callCount++;
          if (callCount == 1) throw Exception('Timeout');
          return '{"stop_reason":"end_turn","content":[{"type":"text","text":"ok"}],"usage":{}}';
        },
      );

      await service.loadModel('qwen2.5-coder-0.5b');

      // First generate fails
      try {
        await service.generate('[{"role":"user","content":"test"}]');
      } catch (_) {}

      // Model should still be loaded
      expect(service.loadState, ModelLoadState.loaded);
      expect(service.loadedModelId, 'qwen2.5-coder-0.5b');

      // Second generate succeeds
      final result =
          await service.generate('[{"role":"user","content":"test2"}]');
      expect(jsonDecode(result)['content'][0]['text'], 'ok');
      service.dispose();
    });

    test('max_tokens passed through correctly', () async {
      int? receivedMaxTokens;

      final service = await createService(
        loadOverride: (_, __, ___) async => true,
        generateOverride: (_, __, maxTokens) async {
          receivedMaxTokens = maxTokens;
          return '{"stop_reason":"end_turn","content":[],"usage":{}}';
        },
      );

      await service.loadModel('qwen2.5-coder-0.5b');
      await service.generate(
        '[{"role":"user","content":"Hi"}]',
        maxTokens: 4096,
      );

      expect(receivedMaxTokens, 4096);
      service.dispose();
    });

    test('tools_json null when no tools', () async {
      String? receivedTools;

      final service = await createService(
        loadOverride: (_, __, ___) async => true,
        generateOverride: (_, tools, __) async {
          receivedTools = tools;
          return '{"stop_reason":"end_turn","content":[],"usage":{}}';
        },
      );

      await service.loadModel('qwen2.5-coder-0.5b');
      await service.generate('[{"role":"user","content":"Hi"}]');

      expect(receivedTools, isNull);
      service.dispose();
    });

    test('load error message is accessible', () async {
      final service = await createService(
        loadOverride: (_, __, ___) async {
          throw Exception('GPU out of memory');
        },
      );

      try {
        await service.loadModel('qwen2.5-coder-0.5b');
      } catch (_) {}

      expect(service.loadState, ModelLoadState.error);
      expect(service.loadError, contains('GPU out of memory'));
      service.dispose();
    });
  });

  group('NO_MODEL auto-reload', () {
    test('reloads and retries on NO_MODEL eviction', () async {
      // Simulates the _executeLLMGenerate logic:
      // First generate throws PlatformException(code: 'NO_MODEL').
      // Service should reset loadedModelId to null, then a subsequent
      // loadModel + generate should succeed on retry.
      int generateCallCount = 0;
      int loadCallCount = 0;

      final service = await createService(
        loadOverride: (_, __, ___) async {
          loadCallCount++;
          return true;
        },
        generateOverride: (_, __, ___) async {
          generateCallCount++;
          if (generateCallCount == 1) {
            throw PlatformException(
              code: 'NO_MODEL',
              message: 'Model evicted by OS memory pressure',
            );
          }
          return '{"stop_reason":"end_turn","content":[{"type":"text","text":"recovered"}],"usage":{}}';
        },
      );

      // Initial load
      await service.loadModel('qwen2.5-coder-0.5b');
      expect(loadCallCount, 1);

      // First generate throws NO_MODEL — service resets loadedModelId
      try {
        await service.generate('[{"role":"user","content":"test"}]');
        fail('Should have thrown PlatformException');
      } on PlatformException catch (e) {
        expect(e.code, 'NO_MODEL');
      }

      // After NO_MODEL, loadedModelId should be null and state unloaded
      expect(service.loadedModelId, isNull);
      expect(service.loadState, ModelLoadState.unloaded);

      // Simulate auto-reload like _executeLLMGenerate does
      await service.loadModel('qwen2.5-coder-0.5b');
      expect(loadCallCount, 2);

      final result = await service.generate(
        '[{"role":"user","content":"retry"}]',
      );
      final parsed = jsonDecode(result);
      expect(parsed['content'][0]['text'], 'recovered');
      expect(generateCallCount, 2);
      service.dispose();
    });

    test('NO_MODEL without modelId rethrows', () async {
      // If we don't know which model to reload, we can't auto-recover.
      // The _executeLLMGenerate code checks `modelId != null` before
      // attempting reload. Without it, the PlatformException propagates.
      final service = await createService(
        loadOverride: (_, __, ___) async => true,
        generateOverride: (_, __, ___) async {
          throw PlatformException(
            code: 'NO_MODEL',
            message: 'Model evicted',
          );
        },
      );

      await service.loadModel('qwen2.5-coder-0.5b');

      // Generate throws NO_MODEL
      try {
        await service.generate('[{"role":"user","content":"test"}]');
        fail('Should have thrown PlatformException');
      } on PlatformException catch (e) {
        expect(e.code, 'NO_MODEL');
      }

      // After NO_MODEL, state is reset
      expect(service.loadedModelId, isNull);
      expect(service.loadState, ModelLoadState.unloaded);

      // Without a modelId the caller can't reload — attempting generate
      // again without loading throws StateError
      expect(
        () => service.generate('[{"role":"user","content":"retry"}]'),
        throwsA(isA<StateError>()),
      );
      service.dispose();
    });
  });

  group('_executeLLMGenerate edge cases', () {
    test('missing messages_json would throw', () async {
      // _executeLLMGenerate throws ArgumentError when messages_json is null.
      // We verify this through LocalLLMService: generate requires loadedModelId
      // but even before that, the executor checks for messages_json.
      // Here we test the service-level equivalent: generate with empty/invalid input.
      final service = await createService(
        loadOverride: (_, __, ___) async => true,
        generateOverride: (messagesJson, _, __) async {
          // The real native layer would reject empty input
          if (messagesJson.isEmpty) {
            throw ArgumentError('Empty messages');
          }
          return '{"stop_reason":"end_turn","content":[],"usage":{}}';
        },
      );

      await service.loadModel('qwen2.5-coder-0.5b');

      // Generate with empty messages should propagate the error from the
      // override through the service's generate method.
      Object? caughtError;
      try {
        await service.generate('');
      } catch (e) {
        caughtError = e;
      }

      expect(caughtError, isNotNull);
      expect(caughtError, isA<ArgumentError>());
      // After a non-PlatformException error, model should still be loaded
      expect(service.loadState, ModelLoadState.loaded);
      service.dispose();
    });

    test('null tools_json is valid', () async {
      String? receivedTools;

      final service = await createService(
        loadOverride: (_, __, ___) async => true,
        generateOverride: (_, tools, __) async {
          receivedTools = tools;
          return '{"stop_reason":"end_turn","content":[{"type":"text","text":"ok"}],"usage":{}}';
        },
      );

      await service.loadModel('qwen2.5-coder-0.5b');
      final result = await service.generate(
        '[{"role":"user","content":"Hello"}]',
        // toolsJson is not provided, should default to null
      );

      expect(receivedTools, isNull);
      final parsed = jsonDecode(result);
      expect(parsed['content'][0]['text'], 'ok');
      service.dispose();
    });

    test('auto-load when no model loaded but modelId provided', () async {
      // Simulates the _executeLLMGenerate path where loadedModelId is null
      // and modelId is given — should auto-load before generating.
      int loadCallCount = 0;
      final service = await createService(
        loadOverride: (modelId, _, __) async {
          loadCallCount++;
          return true;
        },
        generateOverride: (_, __, ___) async =>
            '{"stop_reason":"end_turn","content":[{"type":"text","text":"auto-loaded"}],"usage":{}}',
      );

      // Don't manually loadModel — verify that calling loadModel + generate
      // in sequence works (mimicking what _executeLLMGenerate does)
      expect(service.loadedModelId, isNull);
      expect(service.loadState, ModelLoadState.unloaded);

      // Simulate the auto-load logic from _executeLLMGenerate:
      // if (modelId != null && llmService.loadedModelId != modelId) { loadModel(); }
      const modelId = 'qwen2.5-coder-0.5b';
      if (service.loadedModelId != modelId) {
        await service.loadModel(modelId);
      }

      expect(loadCallCount, 1);
      expect(service.loadedModelId, modelId);

      final result = await service.generate(
        '[{"role":"user","content":"test"}]',
      );
      expect(jsonDecode(result)['content'][0]['text'], 'auto-loaded');
      service.dispose();
    });

    test('skip load when correct model already loaded', () async {
      int loadCallCount = 0;

      final service = await createService(
        loadOverride: (_, __, ___) async {
          loadCallCount++;
          return true;
        },
        generateOverride: (_, __, ___) async =>
            '{"stop_reason":"end_turn","content":[{"type":"text","text":"reused"}],"usage":{}}',
      );

      // Load model once
      await service.loadModel('qwen2.5-coder-0.5b');
      expect(loadCallCount, 1);

      // Simulate _executeLLMGenerate check: modelId matches loadedModelId
      const modelId = 'qwen2.5-coder-0.5b';
      if (service.loadedModelId != modelId) {
        await service.loadModel(modelId);
      }

      // Should NOT have called loadModel again
      expect(loadCallCount, 1);

      final result = await service.generate(
        '[{"role":"user","content":"test"}]',
      );
      expect(jsonDecode(result)['content'][0]['text'], 'reused');
      service.dispose();
    });

    test('switch model when different model requested', () async {
      final loadLog = <String>[];
      bool unloadCalled = false;

      final service = await createService(
        loadOverride: (modelId, _, __) async {
          loadLog.add(modelId);
          return true;
        },
        unloadModelOverride: () async {
          unloadCalled = true;
        },
        generateOverride: (_, __, ___) async =>
            '{"stop_reason":"end_turn","content":[{"type":"text","text":"switched"}],"usage":{}}',
      );

      // Also create 1.5b model directory
      final dir15b = Directory(
        '${modelsDir.path}/${ModelRegistry.getModelDirName('qwen2.5-coder-1.5b')}',
      );
      await dir15b.create(recursive: true);
      await File('${dir15b.path}/model.bin').writeAsBytes(List.filled(1024, 0));
      await File('${dir15b.path}/ndarray-cache.json').writeAsString('{}');

      // Load 0.5b
      await service.loadModel('qwen2.5-coder-0.5b');
      expect(service.loadedModelId, 'qwen2.5-coder-0.5b');
      expect(unloadCalled, isFalse);

      // Simulate _executeLLMGenerate requesting a different model
      const newModelId = 'qwen2.5-coder-1.5b';
      if (service.loadedModelId != newModelId) {
        await service.loadModel(newModelId);
      }

      // Should have unloaded the old model and loaded the new one
      expect(unloadCalled, isTrue);
      expect(loadLog, ['qwen2.5-coder-0.5b', 'qwen2.5-coder-1.5b']);
      expect(service.loadedModelId, 'qwen2.5-coder-1.5b');

      final result = await service.generate(
        '[{"role":"user","content":"test"}]',
      );
      expect(jsonDecode(result)['content'][0]['text'], 'switched');
      service.dispose();
    });
  });

  group('response formats', () {
    test('text-only response', () async {
      final textResponse = jsonEncode({
        'stop_reason': 'end_turn',
        'content': [
          {'type': 'text', 'text': 'This is a plain text response.'}
        ],
        'usage': {'input_tokens': 10, 'output_tokens': 8},
      });

      final service = await createService(
        loadOverride: (_, __, ___) async => true,
        generateOverride: (_, __, ___) async => textResponse,
      );

      await service.loadModel('qwen2.5-coder-0.5b');
      final result = await service.generate(
        '[{"role":"user","content":"Say something"}]',
      );

      final parsed = jsonDecode(result);
      expect(parsed['stop_reason'], 'end_turn');
      expect(parsed['content'], hasLength(1));
      expect(parsed['content'][0]['type'], 'text');
      expect(parsed['content'][0]['text'], 'This is a plain text response.');
      service.dispose();
    });

    test('tool_use response with multiple tool calls', () async {
      final multiToolResponse = jsonEncode({
        'stop_reason': 'tool_use',
        'content': [
          {'type': 'text', 'text': 'Let me do two things...'},
          {
            'type': 'tool_use',
            'id': 'call_1',
            'name': 'python_execute',
            'input': {'code': 'print(1+1)'}
          },
          {
            'type': 'tool_use',
            'id': 'call_2',
            'name': 'read_file',
            'input': {'path': '/tmp/test.txt'}
          },
        ],
        'usage': {'input_tokens': 20, 'output_tokens': 40},
      });

      final service = await createService(
        loadOverride: (_, __, ___) async => true,
        generateOverride: (_, __, ___) async => multiToolResponse,
      );

      await service.loadModel('qwen2.5-coder-0.5b');
      final result = await service.generate(
        '[{"role":"user","content":"do two things"}]',
        toolsJson: '[{"type":"function","function":{"name":"python_execute"}},{"type":"function","function":{"name":"read_file"}}]',
      );

      final parsed = jsonDecode(result);
      expect(parsed['stop_reason'], 'tool_use');
      expect(parsed['content'], hasLength(3));
      expect(parsed['content'][0]['type'], 'text');
      expect(parsed['content'][1]['type'], 'tool_use');
      expect(parsed['content'][1]['name'], 'python_execute');
      expect(parsed['content'][1]['id'], 'call_1');
      expect(parsed['content'][2]['type'], 'tool_use');
      expect(parsed['content'][2]['name'], 'read_file');
      expect(parsed['content'][2]['id'], 'call_2');
      service.dispose();
    });

    test('empty content array', () async {
      final emptyContent = jsonEncode({
        'stop_reason': 'end_turn',
        'content': [],
        'usage': {'input_tokens': 5, 'output_tokens': 0},
      });

      final service = await createService(
        loadOverride: (_, __, ___) async => true,
        generateOverride: (_, __, ___) async => emptyContent,
      );

      await service.loadModel('qwen2.5-coder-0.5b');
      final result = await service.generate(
        '[{"role":"user","content":"test"}]',
      );

      final parsed = jsonDecode(result);
      expect(parsed['stop_reason'], 'end_turn');
      expect(parsed['content'], isEmpty);
      service.dispose();
    });

    test('response with usage stats', () async {
      final withUsage = jsonEncode({
        'stop_reason': 'end_turn',
        'content': [
          {'type': 'text', 'text': 'Done'}
        ],
        'usage': {
          'input_tokens': 150,
          'output_tokens': 42,
        },
      });

      final service = await createService(
        loadOverride: (_, __, ___) async => true,
        generateOverride: (_, __, ___) async => withUsage,
      );

      await service.loadModel('qwen2.5-coder-0.5b');
      final result = await service.generate(
        '[{"role":"user","content":"test"}]',
      );

      final parsed = jsonDecode(result);
      expect(parsed['usage'], isNotNull);
      expect(parsed['usage']['input_tokens'], 150);
      expect(parsed['usage']['output_tokens'], 42);
      service.dispose();
    });
  });
}
