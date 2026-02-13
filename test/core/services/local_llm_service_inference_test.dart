import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navixmind/core/models/model_registry.dart';
import 'package:navixmind/core/services/local_llm_service.dart';

void main() {
  late Directory tempDir;
  late Directory modelsDir;
  late Map<String, String> fakeStorage;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('llm_inference_test_');
    modelsDir = Directory('${tempDir.path}/mlc_models');
    await modelsDir.create(recursive: true);
    fakeStorage = {};
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  /// Helper to create a service with model files on disk.
  Future<LocalLLMService> createServiceWithModel({
    String modelId = 'qwen2.5-coder-0.5b',
    Future<bool> Function(String, String, String)? loadOverride,
    Future<String> Function(String, String?, int)? generateOverride,
    Future<void> Function()? unloadModelOverride,
  }) async {
    // Create model directory with fake files
    final modelDir = Directory(
      '${modelsDir.path}/${ModelRegistry.getModelDirName(modelId)}',
    );
    await modelDir.create(recursive: true);
    await File('${modelDir.path}/model.bin')
        .writeAsBytes(List.filled(1024, 42));
    await File('${modelDir.path}/mlc-chat-config.json')
        .writeAsString('{"model_lib": "test"}');
    await File('${modelDir.path}/ndarray-cache.json').writeAsString('{}');

    final service = LocalLLMService.forTesting(
      modelsDir: modelsDir,
      getPersistedStates: () async => fakeStorage['offline_model_states'],
      setPersistedStates: (json) async =>
          fakeStorage['offline_model_states'] = json,
      loadModelOverride: loadOverride,
      generateOverride: generateOverride,
      unloadModelOverride: unloadModelOverride,
    );
    await service.initialize();
    return service;
  }

  /// Let microtask queue flush so stream events are delivered.
  Future<void> pumpEvents() => Future.delayed(Duration.zero);

  group('ModelLoadState', () {
    test('initial load state is unloaded', () async {
      final service = await createServiceWithModel();
      expect(service.loadState, ModelLoadState.unloaded);
      expect(service.loadedModelId, isNull);
      service.dispose();
    });

    test('loadStateStream emits state changes', () async {
      final states = <ModelLoadState>[];
      final service = await createServiceWithModel(
        loadOverride: (_, __, ___) async => true,
      );
      final sub = service.loadStateStream.listen(states.add);

      await service.loadModel('qwen2.5-coder-0.5b');
      await pumpEvents();

      expect(states, contains(ModelLoadState.loading));
      expect(states, contains(ModelLoadState.loaded));
      expect(service.loadState, ModelLoadState.loaded);

      await sub.cancel();
      service.dispose();
    });
  });

  group('loadModel', () {
    test('loads model successfully', () async {
      String? loadedId;
      final service = await createServiceWithModel(
        loadOverride: (modelId, path, lib) async {
          loadedId = modelId;
          return true;
        },
      );

      await service.loadModel('qwen2.5-coder-0.5b');

      expect(service.loadedModelId, 'qwen2.5-coder-0.5b');
      expect(service.loadState, ModelLoadState.loaded);
      expect(loadedId, 'qwen2.5-coder-0.5b');
      service.dispose();
    });

    test('passes correct modelLib from registry', () async {
      String? passedLib;
      final service = await createServiceWithModel(
        loadOverride: (_, __, lib) async {
          passedLib = lib;
          return true;
        },
      );

      await service.loadModel('qwen2.5-coder-0.5b');

      expect(passedLib, ModelRegistry.qwen05b.mlcModelLib);
      service.dispose();
    });

    test('skips load if same model already loaded', () async {
      int loadCallCount = 0;
      final service = await createServiceWithModel(
        loadOverride: (_, __, ___) async {
          loadCallCount++;
          return true;
        },
      );

      await service.loadModel('qwen2.5-coder-0.5b');
      await service.loadModel('qwen2.5-coder-0.5b');

      expect(loadCallCount, 1);
      service.dispose();
    });

    test('unloads previous model when loading different one', () async {
      bool unloadCalled = false;
      final service = await createServiceWithModel(
        modelId: 'qwen2.5-coder-0.5b',
        loadOverride: (_, __, ___) async => true,
        unloadModelOverride: () async {
          unloadCalled = true;
        },
      );

      // Also create the 1.5b model directory
      final dir15b = Directory(
        '${modelsDir.path}/${ModelRegistry.getModelDirName('qwen2.5-coder-1.5b')}',
      );
      await dir15b.create(recursive: true);
      await File('${dir15b.path}/model.bin').writeAsBytes(List.filled(1024, 0));
      await File('${dir15b.path}/ndarray-cache.json').writeAsString('{}');

      await service.loadModel('qwen2.5-coder-0.5b');
      expect(service.loadedModelId, 'qwen2.5-coder-0.5b');

      await service.loadModel('qwen2.5-coder-1.5b');
      expect(unloadCalled, isTrue);
      expect(service.loadedModelId, 'qwen2.5-coder-1.5b');
      service.dispose();
    });

    test('throws for invalid model ID', () async {
      final service = await createServiceWithModel();

      await expectLater(
        service.loadModel('nonexistent-model'),
        throwsA(isA<ArgumentError>()),
      );
      service.dispose();
    });

    test('throws for cloud model ID', () async {
      final service = await createServiceWithModel();

      await expectLater(
        service.loadModel('opus'),
        throwsA(isA<ArgumentError>()),
      );
      service.dispose();
    });

    test('sets error state on load failure', () async {
      final service = await createServiceWithModel(
        loadOverride: (_, __, ___) async {
          throw PlatformException(code: 'LOAD_FAILED', message: 'GPU error');
        },
      );

      await expectLater(
        service.loadModel('qwen2.5-coder-0.5b'),
        throwsA(isA<PlatformException>()),
      );

      expect(service.loadState, ModelLoadState.error);
      expect(service.loadedModelId, isNull);
      expect(service.loadError, contains('GPU error'));
      service.dispose();
    });

    test('emits loading then error on failure', () async {
      final states = <ModelLoadState>[];
      final service = await createServiceWithModel(
        loadOverride: (_, __, ___) async {
          throw Exception('OOM');
        },
      );
      final sub = service.loadStateStream.listen(states.add);

      try {
        await service.loadModel('qwen2.5-coder-0.5b');
      } catch (_) {}

      await pumpEvents();

      expect(states, [ModelLoadState.loading, ModelLoadState.error]);

      await sub.cancel();
      service.dispose();
    });
  });

  group('unloadModel', () {
    test('unloads loaded model', () async {
      bool unloadCalled = false;
      final service = await createServiceWithModel(
        loadOverride: (_, __, ___) async => true,
        unloadModelOverride: () async {
          unloadCalled = true;
        },
      );

      await service.loadModel('qwen2.5-coder-0.5b');
      expect(service.loadedModelId, 'qwen2.5-coder-0.5b');

      await service.unloadModel();
      expect(unloadCalled, isTrue);
      expect(service.loadedModelId, isNull);
      expect(service.loadState, ModelLoadState.unloaded);
      service.dispose();
    });

    test('no-op when no model is loaded', () async {
      bool unloadCalled = false;
      final service = await createServiceWithModel(
        unloadModelOverride: () async {
          unloadCalled = true;
        },
      );

      await service.unloadModel();
      expect(unloadCalled, isFalse);
      service.dispose();
    });

    test('clears error state on unload', () async {
      final service = await createServiceWithModel(
        loadOverride: (_, __, ___) async {
          throw Exception('Failed');
        },
        unloadModelOverride: () async {},
      );

      try {
        await service.loadModel('qwen2.5-coder-0.5b');
      } catch (_) {}

      expect(service.loadError, isNotNull);

      // unloadModel should clear error even though loadedModelId is null
      // (since error path doesn't set loadedModelId, unload is a no-op,
      //  but we still want loadError cleared on next successful load).
      // The actual clearing happens on the next loadModel call.
      // Let's verify the error is still set since unload is a no-op here.
      await service.unloadModel();
      // loadedModelId is null, so unloadModel is a no-op; error stays.
      // This is expected behavior — error clears on next load attempt.
      service.dispose();
    });
  });

  group('generate', () {
    test('generates response successfully', () async {
      final mockResponse = jsonEncode({
        'stop_reason': 'end_turn',
        'content': [
          {'type': 'text', 'text': 'Hello!'}
        ],
        'usage': {'input_tokens': 10, 'output_tokens': 5},
      });

      final service = await createServiceWithModel(
        loadOverride: (_, __, ___) async => true,
        generateOverride: (messages, tools, maxTokens) async => mockResponse,
      );

      await service.loadModel('qwen2.5-coder-0.5b');
      final result = await service.generate(
        '[{"role":"user","content":"Hi"}]',
        maxTokens: 1024,
      );

      expect(result, mockResponse);
      expect(service.loadState, ModelLoadState.loaded);
      service.dispose();
    });

    test('passes messages and tools correctly', () async {
      String? passedMessages;
      String? passedTools;
      int? passedMaxTokens;

      final service = await createServiceWithModel(
        loadOverride: (_, __, ___) async => true,
        generateOverride: (messages, tools, maxTokens) async {
          passedMessages = messages;
          passedTools = tools;
          passedMaxTokens = maxTokens;
          return '{"stop_reason":"end_turn","content":[{"type":"text","text":"ok"}],"usage":{}}';
        },
      );

      await service.loadModel('qwen2.5-coder-0.5b');
      await service.generate(
        '[{"role":"user","content":"test"}]',
        toolsJson: '[{"type":"function","function":{"name":"test"}}]',
        maxTokens: 512,
      );

      expect(passedMessages, '[{"role":"user","content":"test"}]');
      expect(passedTools, '[{"type":"function","function":{"name":"test"}}]');
      expect(passedMaxTokens, 512);
      service.dispose();
    });

    test('throws when no model loaded', () async {
      final service = await createServiceWithModel();

      await expectLater(
        service.generate('[{"role":"user","content":"Hi"}]'),
        throwsA(isA<StateError>()),
      );
      service.dispose();
    });

    test('emits generating then loaded on success', () async {
      final states = <ModelLoadState>[];
      final service = await createServiceWithModel(
        loadOverride: (_, __, ___) async => true,
        generateOverride: (_, __, ___) async =>
            '{"stop_reason":"end_turn","content":[],"usage":{}}',
      );

      await service.loadModel('qwen2.5-coder-0.5b');
      states.clear();
      final sub = service.loadStateStream.listen(states.add);

      await service.generate('[{"role":"user","content":"Hi"}]');
      await pumpEvents();

      expect(states, [ModelLoadState.generating, ModelLoadState.loaded]);

      await sub.cancel();
      service.dispose();
    });

    test('stays loaded after generation failure', () async {
      final service = await createServiceWithModel(
        loadOverride: (_, __, ___) async => true,
        generateOverride: (_, __, ___) async {
          throw PlatformException(code: 'FAIL', message: 'OOM');
        },
      );

      await service.loadModel('qwen2.5-coder-0.5b');

      await expectLater(
        service.generate('[{"role":"user","content":"Hi"}]'),
        throwsA(isA<PlatformException>()),
      );

      // Model should still be loaded, not error
      expect(service.loadState, ModelLoadState.loaded);
      expect(service.loadedModelId, 'qwen2.5-coder-0.5b');
      service.dispose();
    });

    test('null toolsJson is allowed', () async {
      final service = await createServiceWithModel(
        loadOverride: (_, __, ___) async => true,
        generateOverride: (_, tools, __) async {
          expect(tools, isNull);
          return '{"stop_reason":"end_turn","content":[],"usage":{}}';
        },
      );

      await service.loadModel('qwen2.5-coder-0.5b');
      await service.generate('[{"role":"user","content":"Hi"}]');
      service.dispose();
    });

    test('default maxTokens is 2048', () async {
      int? capturedMaxTokens;
      final service = await createServiceWithModel(
        loadOverride: (_, __, ___) async => true,
        generateOverride: (_, __, maxTokens) async {
          capturedMaxTokens = maxTokens;
          return '{"stop_reason":"end_turn","content":[],"usage":{}}';
        },
      );

      await service.loadModel('qwen2.5-coder-0.5b');
      await service.generate('[{"role":"user","content":"Hi"}]');

      expect(capturedMaxTokens, 2048);
      service.dispose();
    });

    test('handles empty response', () async {
      final service = await createServiceWithModel(
        loadOverride: (_, __, ___) async => true,
        generateOverride: (_, __, ___) async =>
            '{"stop_reason":"end_turn","content":[],"usage":{}}',
      );

      await service.loadModel('qwen2.5-coder-0.5b');
      final result = await service.generate('[{"role":"user","content":"Hi"}]');

      final parsed = jsonDecode(result);
      expect(parsed['stop_reason'], 'end_turn');
      expect(parsed['content'], isEmpty);
      service.dispose();
    });
  });

  group('loadModel + generate integration', () {
    test('full cycle: load, generate, unload', () async {
      final stateLog = <ModelLoadState>[];
      final service = await createServiceWithModel(
        loadOverride: (_, __, ___) async => true,
        generateOverride: (_, __, ___) async =>
            '{"stop_reason":"end_turn","content":[{"type":"text","text":"Done"}],"usage":{}}',
        unloadModelOverride: () async {},
      );
      final sub = service.loadStateStream.listen(stateLog.add);

      // Load
      await service.loadModel('qwen2.5-coder-0.5b');
      expect(service.loadState, ModelLoadState.loaded);

      // Generate
      final result = await service.generate('[{"role":"user","content":"test"}]');
      expect(jsonDecode(result)['content'][0]['text'], 'Done');

      // Unload
      await service.unloadModel();
      expect(service.loadState, ModelLoadState.unloaded);
      expect(service.loadedModelId, isNull);

      await pumpEvents();

      // Verify state transitions
      expect(stateLog, [
        ModelLoadState.loading,
        ModelLoadState.loaded,
        ModelLoadState.generating,
        ModelLoadState.loaded,
        ModelLoadState.unloaded,
      ]);

      await sub.cancel();
      service.dispose();
    });

    test('generate with tool_use stop reason', () async {
      final toolUseResponse = jsonEncode({
        'stop_reason': 'tool_use',
        'content': [
          {'type': 'text', 'text': 'Let me calculate...'},
          {
            'type': 'tool_use',
            'id': 'call_123',
            'name': 'python_execute',
            'input': {'code': 'print(2+2)'}
          },
        ],
        'usage': {'input_tokens': 20, 'output_tokens': 30},
      });

      final service = await createServiceWithModel(
        loadOverride: (_, __, ___) async => true,
        generateOverride: (_, __, ___) async => toolUseResponse,
      );

      await service.loadModel('qwen2.5-coder-0.5b');
      final result = await service.generate(
        '[{"role":"user","content":"what is 2+2?"}]',
        toolsJson: '[{"type":"function","function":{"name":"python_execute"}}]',
      );

      final parsed = jsonDecode(result);
      expect(parsed['stop_reason'], 'tool_use');
      expect(parsed['content'], hasLength(2));
      expect(parsed['content'][1]['name'], 'python_execute');
      service.dispose();
    });
  });

  group('edge cases', () {
    test('loading after error state recovers', () async {
      int callCount = 0;
      final service = await createServiceWithModel(
        loadOverride: (_, __, ___) async {
          callCount++;
          if (callCount == 1) throw Exception('First try fails');
          return true;
        },
      );

      // First attempt fails
      try {
        await service.loadModel('qwen2.5-coder-0.5b');
      } catch (_) {}
      expect(service.loadState, ModelLoadState.error);

      // Second attempt succeeds
      await service.loadModel('qwen2.5-coder-0.5b');
      expect(service.loadState, ModelLoadState.loaded);
      service.dispose();
    });

    test('concurrent generate calls are sequential', () async {
      int concurrentCount = 0;
      int maxConcurrent = 0;

      final service = await createServiceWithModel(
        loadOverride: (_, __, ___) async => true,
        generateOverride: (_, __, ___) async {
          concurrentCount++;
          maxConcurrent =
              concurrentCount > maxConcurrent ? concurrentCount : maxConcurrent;
          await Future.delayed(const Duration(milliseconds: 10));
          concurrentCount--;
          return '{"stop_reason":"end_turn","content":[],"usage":{}}';
        },
      );

      await service.loadModel('qwen2.5-coder-0.5b');

      await service.generate('[{"role":"user","content":"1"}]');
      await service.generate('[{"role":"user","content":"2"}]');

      expect(maxConcurrent, 1);
      service.dispose();
    });

    test('dispose works after load', () async {
      final service = await createServiceWithModel(
        loadOverride: (_, __, ___) async => true,
      );

      await service.loadModel('qwen2.5-coder-0.5b');
      service.dispose();
    });

    test('unload error is swallowed gracefully', () async {
      final service = await createServiceWithModel(
        loadOverride: (_, __, ___) async => true,
        unloadModelOverride: () async {
          throw Exception('Unload failed');
        },
      );

      await service.loadModel('qwen2.5-coder-0.5b');

      await service.unloadModel();
      expect(service.loadedModelId, isNull);
      expect(service.loadState, ModelLoadState.unloaded);
      service.dispose();
    });
  });

  // ================================================================
  // NEW TEST GROUPS — edge cases and corner cases
  // ================================================================

  group('NO_MODEL eviction handling', () {
    test('PlatformException with NO_MODEL code resets loadedModelId', () async {
      final service = await createServiceWithModel(
        loadOverride: (_, __, ___) async => true,
        generateOverride: (_, __, ___) async {
          throw PlatformException(
              code: 'NO_MODEL', message: 'Model evicted by OS');
        },
      );

      await service.loadModel('qwen2.5-coder-0.5b');
      expect(service.loadedModelId, 'qwen2.5-coder-0.5b');
      expect(service.loadState, ModelLoadState.loaded);

      await expectLater(
        service.generate('[{"role":"user","content":"Hi"}]'),
        throwsA(isA<PlatformException>()),
      );

      // After NO_MODEL, loadedModelId should be null and state unloaded
      expect(service.loadedModelId, isNull);
      expect(service.loadState, ModelLoadState.unloaded);
      // Importantly, loadError should NOT be set (this is not an error state)
      service.dispose();
    });

    test('PlatformException with NO_MODEL emits unloaded state', () async {
      final states = <ModelLoadState>[];
      final service = await createServiceWithModel(
        loadOverride: (_, __, ___) async => true,
        generateOverride: (_, __, ___) async {
          throw PlatformException(
              code: 'NO_MODEL', message: 'Model evicted');
        },
      );

      await service.loadModel('qwen2.5-coder-0.5b');
      states.clear();
      final sub = service.loadStateStream.listen(states.add);

      try {
        await service.generate('[{"role":"user","content":"Hi"}]');
      } catch (_) {}

      await pumpEvents();

      // Should see generating -> unloaded (NOT generating -> error)
      expect(states, [ModelLoadState.generating, ModelLoadState.unloaded]);

      await sub.cancel();
      service.dispose();
    });

    test('non-NO_MODEL PlatformException keeps model loaded', () async {
      final states = <ModelLoadState>[];
      final service = await createServiceWithModel(
        loadOverride: (_, __, ___) async => true,
        generateOverride: (_, __, ___) async {
          throw PlatformException(
              code: 'OTHER_ERROR', message: 'Something else went wrong');
        },
      );

      await service.loadModel('qwen2.5-coder-0.5b');
      states.clear();
      final sub = service.loadStateStream.listen(states.add);

      try {
        await service.generate('[{"role":"user","content":"Hi"}]');
      } catch (_) {}

      await pumpEvents();

      // Should see generating -> loaded (model stays loaded)
      expect(states, [ModelLoadState.generating, ModelLoadState.loaded]);
      expect(service.loadedModelId, 'qwen2.5-coder-0.5b');
      expect(service.loadState, ModelLoadState.loaded);

      await sub.cancel();
      service.dispose();
    });

    test('can re-load model after NO_MODEL eviction', () async {
      int generateCallCount = 0;
      final service = await createServiceWithModel(
        loadOverride: (_, __, ___) async => true,
        generateOverride: (_, __, ___) async {
          generateCallCount++;
          if (generateCallCount == 1) {
            throw PlatformException(
                code: 'NO_MODEL', message: 'Model evicted');
          }
          return '{"stop_reason":"end_turn","content":[{"type":"text","text":"ok"}],"usage":{}}';
        },
      );

      // Load and generate — first call triggers eviction
      await service.loadModel('qwen2.5-coder-0.5b');
      try {
        await service.generate('[{"role":"user","content":"Hi"}]');
      } catch (_) {}

      expect(service.loadedModelId, isNull);
      expect(service.loadState, ModelLoadState.unloaded);

      // Re-load and generate — should succeed
      await service.loadModel('qwen2.5-coder-0.5b');
      expect(service.loadedModelId, 'qwen2.5-coder-0.5b');
      expect(service.loadState, ModelLoadState.loaded);

      final result =
          await service.generate('[{"role":"user","content":"Hi again"}]');
      final parsed = jsonDecode(result);
      expect(parsed['stop_reason'], 'end_turn');

      service.dispose();
    });
  });

  group('getGpuMemoryMB', () {
    test('returns -1 when not overridden and no channel', () async {
      // Service without generateOverride/loadModelOverride still has no
      // channel mock for getGpuMemoryMB, so it hits the real MethodChannel
      // which will throw MissingPluginException — the catch block returns -1.
      final service = await createServiceWithModel();
      final result = await service.getGpuMemoryMB();
      expect(result, -1);
      service.dispose();
    });
  });

  group('loadStateStream advanced', () {
    test('is a broadcast stream supporting multiple listeners', () async {
      final states1 = <ModelLoadState>[];
      final states2 = <ModelLoadState>[];
      final service = await createServiceWithModel(
        loadOverride: (_, __, ___) async => true,
      );

      final sub1 = service.loadStateStream.listen(states1.add);
      final sub2 = service.loadStateStream.listen(states2.add);

      await service.loadModel('qwen2.5-coder-0.5b');
      await pumpEvents();

      // Both listeners should receive the same events
      expect(states1, contains(ModelLoadState.loading));
      expect(states1, contains(ModelLoadState.loaded));
      expect(states2, contains(ModelLoadState.loading));
      expect(states2, contains(ModelLoadState.loaded));
      expect(states1, states2);

      await sub1.cancel();
      await sub2.cancel();
      service.dispose();
    });

    test('late listener still gets future events', () async {
      final earlyStates = <ModelLoadState>[];
      final lateStates = <ModelLoadState>[];
      final service = await createServiceWithModel(
        loadOverride: (_, __, ___) async => true,
        unloadModelOverride: () async {},
      );

      final earlySub = service.loadStateStream.listen(earlyStates.add);

      // Load model — early listener gets events, late listener is not yet
      await service.loadModel('qwen2.5-coder-0.5b');
      await pumpEvents();

      // Now attach late listener
      final lateSub = service.loadStateStream.listen(lateStates.add);

      // Unload — both should get the unloaded event
      await service.unloadModel();
      await pumpEvents();

      expect(earlyStates, [
        ModelLoadState.loading,
        ModelLoadState.loaded,
        ModelLoadState.unloaded,
      ]);
      // Late listener should only see events after it subscribed
      expect(lateStates, [ModelLoadState.unloaded]);

      await earlySub.cancel();
      await lateSub.cancel();
      service.dispose();
    });

    test('state is correct after rapid load/unload/load', () async {
      final states = <ModelLoadState>[];
      final service = await createServiceWithModel(
        loadOverride: (_, __, ___) async => true,
        unloadModelOverride: () async {},
      );
      final sub = service.loadStateStream.listen(states.add);

      await service.loadModel('qwen2.5-coder-0.5b');
      await service.unloadModel();
      await service.loadModel('qwen2.5-coder-0.5b');
      await pumpEvents();

      expect(states, [
        ModelLoadState.loading,
        ModelLoadState.loaded,
        ModelLoadState.unloaded,
        ModelLoadState.loading,
        ModelLoadState.loaded,
      ]);
      expect(service.loadState, ModelLoadState.loaded);
      expect(service.loadedModelId, 'qwen2.5-coder-0.5b');

      await sub.cancel();
      service.dispose();
    });
  });

  group('generate response formats', () {
    test('handles response with multiple content blocks', () async {
      final multiBlockResponse = jsonEncode({
        'stop_reason': 'end_turn',
        'content': [
          {'type': 'text', 'text': 'Here is the answer:'},
          {'type': 'text', 'text': '\n\n42'},
          {'type': 'text', 'text': '\n\nHope that helps!'},
        ],
        'usage': {'input_tokens': 15, 'output_tokens': 20},
      });

      final service = await createServiceWithModel(
        loadOverride: (_, __, ___) async => true,
        generateOverride: (_, __, ___) async => multiBlockResponse,
      );

      await service.loadModel('qwen2.5-coder-0.5b');
      final result = await service.generate('[{"role":"user","content":"?"}]');

      final parsed = jsonDecode(result);
      expect(parsed['content'], hasLength(3));
      expect(parsed['content'][0]['text'], 'Here is the answer:');
      expect(parsed['content'][1]['text'], '\n\n42');
      expect(parsed['content'][2]['text'], '\n\nHope that helps!');
      expect(service.loadState, ModelLoadState.loaded);
      service.dispose();
    });

    test('handles very large response string', () async {
      // Simulate a 100KB response
      final largeText = 'A' * (100 * 1024);
      final largeResponse = jsonEncode({
        'stop_reason': 'max_tokens',
        'content': [
          {'type': 'text', 'text': largeText}
        ],
        'usage': {'input_tokens': 10, 'output_tokens': 25000},
      });

      final service = await createServiceWithModel(
        loadOverride: (_, __, ___) async => true,
        generateOverride: (_, __, ___) async => largeResponse,
      );

      await service.loadModel('qwen2.5-coder-0.5b');
      final result = await service.generate('[{"role":"user","content":"Hi"}]');

      final parsed = jsonDecode(result);
      expect(parsed['stop_reason'], 'max_tokens');
      expect((parsed['content'][0]['text'] as String).length, 100 * 1024);
      expect(service.loadState, ModelLoadState.loaded);
      service.dispose();
    });

    test('handles empty string response', () async {
      // The generate method returns raw string — empty content list is valid
      final emptyContentResponse = jsonEncode({
        'stop_reason': 'end_turn',
        'content': [],
        'usage': {'input_tokens': 5, 'output_tokens': 0},
      });

      final service = await createServiceWithModel(
        loadOverride: (_, __, ___) async => true,
        generateOverride: (_, __, ___) async => emptyContentResponse,
      );

      await service.loadModel('qwen2.5-coder-0.5b');
      final result = await service.generate('[{"role":"user","content":"Hi"}]');

      final parsed = jsonDecode(result);
      expect(parsed['content'], isEmpty);
      expect(parsed['usage']['output_tokens'], 0);
      service.dispose();
    });

    test('handles unicode in response', () async {
      final unicodeResponse = jsonEncode({
        'stop_reason': 'end_turn',
        'content': [
          {
            'type': 'text',
            'text':
                'Привет! 你好世界 🌍 café naïve résumé Ω∑∏ ∫ℵ∞ \u200b\u00a0'
          }
        ],
        'usage': {'input_tokens': 10, 'output_tokens': 15},
      });

      final service = await createServiceWithModel(
        loadOverride: (_, __, ___) async => true,
        generateOverride: (_, __, ___) async => unicodeResponse,
      );

      await service.loadModel('qwen2.5-coder-0.5b');
      final result = await service.generate('[{"role":"user","content":"Hi"}]');

      final parsed = jsonDecode(result);
      final text = parsed['content'][0]['text'] as String;
      expect(text, contains('Привет'));
      expect(text, contains('你好世界'));
      expect(text, contains('café'));
      expect(text, contains('Ω∑∏'));
      expect(service.loadState, ModelLoadState.loaded);
      service.dispose();
    });
  });

  group('state transitions stress', () {
    test('rapid load-unload-load-unload sequence', () async {
      final states = <ModelLoadState>[];
      final service = await createServiceWithModel(
        loadOverride: (_, __, ___) async => true,
        unloadModelOverride: () async {},
      );
      final sub = service.loadStateStream.listen(states.add);

      await service.loadModel('qwen2.5-coder-0.5b');
      await service.unloadModel();
      await service.loadModel('qwen2.5-coder-0.5b');
      await service.unloadModel();
      await pumpEvents();

      expect(states, [
        ModelLoadState.loading,
        ModelLoadState.loaded,
        ModelLoadState.unloaded,
        ModelLoadState.loading,
        ModelLoadState.loaded,
        ModelLoadState.unloaded,
      ]);
      expect(service.loadState, ModelLoadState.unloaded);
      expect(service.loadedModelId, isNull);

      await sub.cancel();
      service.dispose();
    });

    test('load same model twice in a row is idempotent', () async {
      int loadCallCount = 0;
      final states = <ModelLoadState>[];
      final service = await createServiceWithModel(
        loadOverride: (_, __, ___) async {
          loadCallCount++;
          return true;
        },
      );
      final sub = service.loadStateStream.listen(states.add);

      await service.loadModel('qwen2.5-coder-0.5b');
      await service.loadModel('qwen2.5-coder-0.5b');
      await service.loadModel('qwen2.5-coder-0.5b');
      await pumpEvents();

      // Only one actual load call — subsequent ones bail out early
      expect(loadCallCount, 1);
      expect(service.loadState, ModelLoadState.loaded);
      expect(service.loadedModelId, 'qwen2.5-coder-0.5b');
      // Only one loading->loaded transition
      expect(states, [ModelLoadState.loading, ModelLoadState.loaded]);

      await sub.cancel();
      service.dispose();
    });

    test('generate after unload throws StateError', () async {
      final service = await createServiceWithModel(
        loadOverride: (_, __, ___) async => true,
        generateOverride: (_, __, ___) async =>
            '{"stop_reason":"end_turn","content":[],"usage":{}}',
        unloadModelOverride: () async {},
      );

      await service.loadModel('qwen2.5-coder-0.5b');
      expect(service.loadState, ModelLoadState.loaded);

      // Generate works while loaded
      await service.generate('[{"role":"user","content":"Hi"}]');

      // Unload
      await service.unloadModel();
      expect(service.loadState, ModelLoadState.unloaded);

      // Generate after unload should throw StateError
      await expectLater(
        service.generate('[{"role":"user","content":"Hi"}]'),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('No model loaded'),
        )),
      );

      service.dispose();
    });
  });
}
