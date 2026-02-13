import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:navixmind/core/models/model_registry.dart';
import 'package:navixmind/core/services/local_llm_service.dart';

void main() {
  late Directory tempDir;
  late Directory modelsDir;
  late Map<String, String> fakeStorage;
  late LocalLLMService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('local_llm_test_');
    modelsDir = Directory('${tempDir.path}/mlc_models');
    await modelsDir.create(recursive: true);
    fakeStorage = {};
    service = LocalLLMService.forTesting(
      modelsDir: modelsDir,
      getPersistedStates: () async => fakeStorage['offline_model_states'],
      setPersistedStates: (json) async =>
          fakeStorage['offline_model_states'] = json,
    );
  });

  tearDown(() async {
    service.dispose();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('initialize', () {
    test('creates state entries for all offline models', () async {
      await service.initialize();
      final states = service.modelStates;

      for (final model in ModelRegistry.offlineModels) {
        expect(states.containsKey(model.id), isTrue,
            reason: 'Should have state for ${model.id}');
        expect(
            states[model.id]!.downloadState, ModelDownloadState.notDownloaded);
      }
    });

    test('does not create state entries for cloud models', () async {
      await service.initialize();
      final states = service.modelStates;

      for (final model in ModelRegistry.cloudModels) {
        expect(states.containsKey(model.id), isFalse,
            reason: 'Should NOT have state for cloud model ${model.id}');
      }
    });

    test('detects already-downloaded model on disk', () async {
      // Create a fake downloaded model directory with a file
      final modelDir = Directory(
        '${modelsDir.path}/${ModelRegistry.getModelDirName('qwen2.5-coder-0.5b')}',
      );
      await modelDir.create(recursive: true);
      final fakeFile = File('${modelDir.path}/model.bin');
      await fakeFile.writeAsBytes(List.filled(1024, 42)); // 1 KB fake model
      await File('${modelDir.path}/ndarray-cache.json').writeAsString('{}');

      await service.initialize();
      final states = service.modelStates;

      expect(states['qwen2.5-coder-0.5b']!.downloadState,
          ModelDownloadState.downloaded);
      expect(states['qwen2.5-coder-0.5b']!.downloadProgress, 1.0);
      expect(states['qwen2.5-coder-0.5b']!.diskUsageBytes, 1026); // 1024 + 2 (ndarray-cache.json)
    });

    test('empty model directory is not considered downloaded', () async {
      final modelDir = Directory(
        '${modelsDir.path}/${ModelRegistry.getModelDirName('qwen2.5-coder-0.5b')}',
      );
      await modelDir.create(recursive: true);

      await service.initialize();
      final states = service.modelStates;

      expect(states['qwen2.5-coder-0.5b']!.downloadState,
          ModelDownloadState.notDownloaded);
    });

    test('handles missing models directory gracefully', () async {
      // Delete the models directory
      if (await modelsDir.exists()) {
        await modelsDir.delete(recursive: true);
      }

      await service.initialize();
      final states = service.modelStates;

      for (final model in ModelRegistry.offlineModels) {
        expect(
            states[model.id]!.downloadState, ModelDownloadState.notDownloaded);
      }
    });

    test('restores persisted state but disk scan overrides if files missing',
        () async {
      // Pre-persist state claiming model is downloaded
      fakeStorage['offline_model_states'] = jsonEncode({
        'qwen2.5-coder-1.5b': {
          'downloadState': 'downloaded',
          'diskUsageBytes': 500000,
        },
      });

      // But model is not actually on disk, so disk scan should reset it
      await service.initialize();
      final states = service.modelStates;

      expect(states['qwen2.5-coder-1.5b']!.downloadState,
          ModelDownloadState.notDownloaded);
    });

    test('persisted state + actual files on disk = downloaded', () async {
      // Create the model dir with a file
      final modelDir = Directory(
        '${modelsDir.path}/${ModelRegistry.getModelDirName('qwen2.5-coder-1.5b')}',
      );
      await modelDir.create(recursive: true);
      await File('${modelDir.path}/weights.bin')
          .writeAsBytes(List.filled(2048, 0));
      await File('${modelDir.path}/ndarray-cache.json').writeAsString('{}');

      fakeStorage['offline_model_states'] = jsonEncode({
        'qwen2.5-coder-1.5b': {
          'downloadState': 'downloaded',
          'diskUsageBytes': 500000,
        },
      });

      await service.initialize();
      final states = service.modelStates;

      expect(states['qwen2.5-coder-1.5b']!.downloadState,
          ModelDownloadState.downloaded);
      // Disk usage is recalculated from actual files
      expect(states['qwen2.5-coder-1.5b']!.diskUsageBytes, 2050); // 2048 + 2 (ndarray-cache.json)
    });

    test('handles corrupted persisted JSON gracefully', () async {
      fakeStorage['offline_model_states'] = 'not valid json!!!';

      await service.initialize();
      final states = service.modelStates;

      // Should still have all offline model states with defaults
      for (final model in ModelRegistry.offlineModels) {
        expect(states.containsKey(model.id), isTrue);
      }
    });

    test('ignores unknown model IDs in persisted state', () async {
      fakeStorage['offline_model_states'] = jsonEncode({
        'unknown-model-xyz': {
          'downloadState': 'downloaded',
          'diskUsageBytes': 1000,
        },
      });

      await service.initialize();
      final states = service.modelStates;

      expect(states.containsKey('unknown-model-xyz'), isFalse);
      expect(states.length, ModelRegistry.offlineModels.length);
    });

    test('detects multiple downloaded models', () async {
      for (final modelId in ['qwen2.5-coder-0.5b', 'qwen2.5-coder-3b']) {
        final modelDir = Directory(
          '${modelsDir.path}/${ModelRegistry.getModelDirName(modelId)}',
        );
        await modelDir.create(recursive: true);
        await File('${modelDir.path}/model.bin')
            .writeAsBytes(List.filled(256, 0));
        await File('${modelDir.path}/ndarray-cache.json')
            .writeAsString('{}');
      }

      await service.initialize();
      final states = service.modelStates;

      expect(states['qwen2.5-coder-0.5b']!.downloadState,
          ModelDownloadState.downloaded);
      expect(states['qwen2.5-coder-3b']!.downloadState,
          ModelDownloadState.downloaded);
      expect(states['qwen2.5-coder-1.5b']!.downloadState,
          ModelDownloadState.notDownloaded);
    });
  });

  group('stateStream', () {
    test('emits after initialize', () async {
      final completer = Completer<Map<String, OfflineModelState>>();
      service.stateStream.first.then(completer.complete);

      await service.initialize();

      final states = await completer.future;
      expect(states.length, ModelRegistry.offlineModels.length);
    });

    test('emits after deleteModel', () async {
      // Set up a "downloaded" model
      final modelDir = Directory(
        '${modelsDir.path}/${ModelRegistry.getModelDirName('qwen2.5-coder-0.5b')}',
      );
      await modelDir.create(recursive: true);
      await File('${modelDir.path}/model.bin')
          .writeAsBytes(List.filled(512, 0));

      await service.initialize();

      final emissions = <Map<String, OfflineModelState>>[];
      final sub = service.stateStream.listen(emissions.add);

      await service.deleteModel('qwen2.5-coder-0.5b');

      // Allow stream to propagate
      await Future.delayed(Duration.zero);

      expect(emissions, isNotEmpty);
      expect(emissions.last['qwen2.5-coder-0.5b']!.downloadState,
          ModelDownloadState.notDownloaded);

      await sub.cancel();
    });

    test('is a broadcast stream (multiple listeners)', () async {
      final emissions1 = <Map<String, OfflineModelState>>[];
      final emissions2 = <Map<String, OfflineModelState>>[];

      final sub1 = service.stateStream.listen(emissions1.add);
      final sub2 = service.stateStream.listen(emissions2.add);

      await service.initialize();
      await Future.delayed(Duration.zero);

      expect(emissions1, isNotEmpty);
      expect(emissions2, isNotEmpty);

      await sub1.cancel();
      await sub2.cancel();
    });
  });

  group('modelStates', () {
    test('returns unmodifiable map', () async {
      await service.initialize();
      final states = service.modelStates;

      expect(
          () => (states as Map<String, OfflineModelState>)['new_key'] =
              OfflineModelState(modelId: 'new_key'),
          throwsA(isA<UnsupportedError>()));
    });

    test('returns empty map before initialize', () {
      expect(service.modelStates, isEmpty);
    });
  });

  group('isModelDownloaded', () {
    test('returns false when directory does not exist', () async {
      final result = await service.isModelDownloaded('qwen2.5-coder-0.5b');
      expect(result, isFalse);
    });

    test('returns false when directory exists but is empty', () async {
      final modelDir = Directory(
        '${modelsDir.path}/${ModelRegistry.getModelDirName('qwen2.5-coder-0.5b')}',
      );
      await modelDir.create(recursive: true);

      final result = await service.isModelDownloaded('qwen2.5-coder-0.5b');
      expect(result, isFalse);
    });

    test('returns true when directory has manifest file', () async {
      final modelDir = Directory(
        '${modelsDir.path}/${ModelRegistry.getModelDirName('qwen2.5-coder-0.5b')}',
      );
      await modelDir.create(recursive: true);
      await File('${modelDir.path}/model.bin').writeAsString('data');
      await File('${modelDir.path}/ndarray-cache.json').writeAsString('{}');

      final result = await service.isModelDownloaded('qwen2.5-coder-0.5b');
      expect(result, isTrue);
    });

    test('returns false when directory has files but no manifest', () async {
      final modelDir = Directory(
        '${modelsDir.path}/${ModelRegistry.getModelDirName('qwen2.5-coder-0.5b')}',
      );
      await modelDir.create(recursive: true);
      await File('${modelDir.path}/model.bin').writeAsString('data');

      final result = await service.isModelDownloaded('qwen2.5-coder-0.5b');
      expect(result, isFalse);
    });

    test('returns true with tensor-cache.json manifest', () async {
      final modelDir = Directory(
        '${modelsDir.path}/${ModelRegistry.getModelDirName('qwen2.5-coder-3b')}',
      );
      await modelDir.create(recursive: true);
      await File('${modelDir.path}/tensor-cache.json').writeAsString('{}');

      final result = await service.isModelDownloaded('qwen2.5-coder-3b');
      expect(result, isTrue);
    });
  });

  group('getModelDiskUsage', () {
    test('returns 0 when directory does not exist', () async {
      final result = await service.getModelDiskUsage('qwen2.5-coder-0.5b');
      expect(result, 0);
    });

    test('returns 0 when directory is empty', () async {
      final modelDir = Directory(
        '${modelsDir.path}/${ModelRegistry.getModelDirName('qwen2.5-coder-0.5b')}',
      );
      await modelDir.create(recursive: true);

      final result = await service.getModelDiskUsage('qwen2.5-coder-0.5b');
      expect(result, 0);
    });

    test('calculates total size of all files', () async {
      final modelDir = Directory(
        '${modelsDir.path}/${ModelRegistry.getModelDirName('qwen2.5-coder-0.5b')}',
      );
      await modelDir.create(recursive: true);
      await File('${modelDir.path}/file1.bin')
          .writeAsBytes(List.filled(1000, 0));
      await File('${modelDir.path}/file2.bin')
          .writeAsBytes(List.filled(2000, 0));

      final result = await service.getModelDiskUsage('qwen2.5-coder-0.5b');
      expect(result, 3000);
    });

    test('includes files in subdirectories', () async {
      final modelDir = Directory(
        '${modelsDir.path}/${ModelRegistry.getModelDirName('qwen2.5-coder-0.5b')}',
      );
      await modelDir.create(recursive: true);
      await File('${modelDir.path}/model.bin')
          .writeAsBytes(List.filled(500, 0));
      final subDir = Directory('${modelDir.path}/params');
      await subDir.create();
      await File('${subDir.path}/config.json')
          .writeAsBytes(List.filled(100, 0));

      final result = await service.getModelDiskUsage('qwen2.5-coder-0.5b');
      expect(result, 600);
    });
  });

  group('deleteModel', () {
    test('deletes model directory and resets state', () async {
      // Create a fake downloaded model
      final modelDir = Directory(
        '${modelsDir.path}/${ModelRegistry.getModelDirName('qwen2.5-coder-0.5b')}',
      );
      await modelDir.create(recursive: true);
      await File('${modelDir.path}/model.bin')
          .writeAsBytes(List.filled(512, 0));
      await File('${modelDir.path}/ndarray-cache.json').writeAsString('{}');

      await service.initialize();
      expect(service.modelStates['qwen2.5-coder-0.5b']!.downloadState,
          ModelDownloadState.downloaded);

      await service.deleteModel('qwen2.5-coder-0.5b');

      expect(service.modelStates['qwen2.5-coder-0.5b']!.downloadState,
          ModelDownloadState.notDownloaded);
      expect(await modelDir.exists(), isFalse);
    });

    test('handles deleting non-existent model directory', () async {
      await service.initialize();

      // Should not throw
      await service.deleteModel('qwen2.5-coder-0.5b');

      expect(service.modelStates['qwen2.5-coder-0.5b']!.downloadState,
          ModelDownloadState.notDownloaded);
    });

    test('persists state after deletion', () async {
      final modelDir = Directory(
        '${modelsDir.path}/${ModelRegistry.getModelDirName('qwen2.5-coder-0.5b')}',
      );
      await modelDir.create(recursive: true);
      await File('${modelDir.path}/model.bin')
          .writeAsBytes(List.filled(512, 0));
      await File('${modelDir.path}/ndarray-cache.json').writeAsString('{}');

      await service.initialize();
      await service.deleteModel('qwen2.5-coder-0.5b');

      // Verify persisted state
      final persisted = fakeStorage['offline_model_states'];
      expect(persisted, isNotNull);
      final map = jsonDecode(persisted!) as Map<String, dynamic>;
      expect(map['qwen2.5-coder-0.5b']['downloadState'], 'notDownloaded');
    });

    test('deletes directory with nested files', () async {
      final modelDir = Directory(
        '${modelsDir.path}/${ModelRegistry.getModelDirName('qwen2.5-coder-3b')}',
      );
      await modelDir.create(recursive: true);
      final subDir = Directory('${modelDir.path}/params');
      await subDir.create();
      await File('${subDir.path}/config.json').writeAsString('{}');
      await File('${modelDir.path}/model.bin')
          .writeAsBytes(List.filled(100, 0));
      await File('${modelDir.path}/ndarray-cache.json').writeAsString('{}');

      await service.initialize();
      await service.deleteModel('qwen2.5-coder-3b');

      expect(await modelDir.exists(), isFalse);
      expect(service.modelStates['qwen2.5-coder-3b']!.downloadState,
          ModelDownloadState.notDownloaded);
    });
  });

  group('stub methods', () {
    test('downloadModel throws ArgumentError for invalid model', () async {
      await service.initialize();
      expect(
        () => service.downloadModel('nonexistent-model'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('loadModel throws ArgumentError for invalid model', () async {
      await service.initialize();
      await expectLater(
        service.loadModel('nonexistent-model'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('generate throws StateError when no model loaded', () async {
      await service.initialize();
      expect(
        () => service.generate('Hello'),
        throwsA(isA<StateError>()),
      );
    });

    test('unloadModel clears loadedModelId', () async {
      await service.initialize();
      await service.unloadModel();
      expect(service.loadedModelId, isNull);
    });
  });

  group('getModelsDirectory', () {
    test('returns the overridden directory in test mode', () async {
      final dir = await service.getModelsDirectory();
      expect(dir.path, modelsDir.path);
    });
  });

  group('getModelDirectory', () {
    test('returns correct path for model', () async {
      final dir = await service.getModelDirectory('qwen2.5-coder-0.5b');
      expect(dir.path, '${modelsDir.path}/qwen2.5-coder-0.5b');
    });

    test('returns correct path for each offline model', () async {
      for (final model in ModelRegistry.offlineModels) {
        final dir = await service.getModelDirectory(model.id);
        expect(dir.path, '${modelsDir.path}/${model.id}');
      }
    });
  });

  group('persistence', () {
    test('initialize persists scanned state', () async {
      final modelDir = Directory(
        '${modelsDir.path}/${ModelRegistry.getModelDirName('qwen2.5-coder-3b')}',
      );
      await modelDir.create(recursive: true);
      await File('${modelDir.path}/model.bin')
          .writeAsBytes(List.filled(4096, 0));
      await File('${modelDir.path}/ndarray-cache.json').writeAsString('{}');

      await service.initialize();

      final persisted = fakeStorage['offline_model_states'];
      expect(persisted, isNotNull);
      final map = jsonDecode(persisted!) as Map<String, dynamic>;
      expect(map['qwen2.5-coder-3b']['downloadState'], 'downloaded');
      expect(map['qwen2.5-coder-3b']['diskUsageBytes'], 4098); // 4096 + 2 (ndarray-cache.json)
      expect(map['qwen2.5-coder-0.5b']['downloadState'], 'notDownloaded');
    });

    test('persisted state survives re-initialization', () async {
      // First init: create a downloaded model
      final modelDir = Directory(
        '${modelsDir.path}/${ModelRegistry.getModelDirName('qwen2.5-coder-0.5b')}',
      );
      await modelDir.create(recursive: true);
      await File('${modelDir.path}/model.bin')
          .writeAsBytes(List.filled(256, 0));
      await File('${modelDir.path}/ndarray-cache.json').writeAsString('{}');

      await service.initialize();
      service.dispose();

      // Second init: new service instance with same storage
      final service2 = LocalLLMService.forTesting(
        modelsDir: modelsDir,
        getPersistedStates: () async => fakeStorage['offline_model_states'],
        setPersistedStates: (json) async =>
            fakeStorage['offline_model_states'] = json,
      );
      await service2.initialize();

      expect(service2.modelStates['qwen2.5-coder-0.5b']!.downloadState,
          ModelDownloadState.downloaded);
      expect(service2.modelStates['qwen2.5-coder-0.5b']!.diskUsageBytes, 258); // 256 + 2 (ndarray-cache.json)

      service2.dispose();
    });

    test('persisted downloading state resets to notDownloaded on reinitialize',
        () async {
      fakeStorage['offline_model_states'] = jsonEncode({
        'qwen2.5-coder-0.5b': {
          'downloadState': 'downloading',
          'diskUsageBytes': null,
        },
      });

      await service.initialize();

      // Downloading state resets on reinitialize because the Kotlin download
      // executor no longer exists after app restart.
      final state = service.modelStates['qwen2.5-coder-0.5b']!;
      expect(state.downloadState, ModelDownloadState.notDownloaded);
    });
  });

  group('loadedModelId', () {
    test('is null initially', () {
      expect(service.loadedModelId, isNull);
    });

    test('is null after initialize', () async {
      await service.initialize();
      expect(service.loadedModelId, isNull);
    });

    test('is null after unloadModel', () async {
      await service.initialize();
      await service.unloadModel();
      expect(service.loadedModelId, isNull);
    });
  });
}
