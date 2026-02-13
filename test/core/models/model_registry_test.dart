import 'package:flutter_test/flutter_test.dart';
import 'package:navixmind/core/models/model_registry.dart';

void main() {
  group('ModelProvider', () {
    test('has cloud and offline values', () {
      expect(ModelProvider.values, containsAll([ModelProvider.cloud, ModelProvider.offline]));
      expect(ModelProvider.values.length, 2);
    });
  });

  group('ModelDownloadState', () {
    test('has all expected values', () {
      expect(ModelDownloadState.values, containsAll([
        ModelDownloadState.notDownloaded,
        ModelDownloadState.downloading,
        ModelDownloadState.downloaded,
        ModelDownloadState.error,
      ]));
      expect(ModelDownloadState.values.length, 4);
    });
  });

  group('ModelInfo', () {
    test('isCloud returns true for cloud provider', () {
      const model = ModelInfo(
        id: 'test',
        displayName: 'Test',
        description: 'Test model',
        provider: ModelProvider.cloud,
      );
      expect(model.isCloud, isTrue);
      expect(model.isOffline, isFalse);
    });

    test('isOffline returns true for offline provider', () {
      const model = ModelInfo(
        id: 'test',
        displayName: 'Test',
        description: 'Test model',
        provider: ModelProvider.offline,
      );
      expect(model.isOffline, isTrue);
      expect(model.isCloud, isFalse);
    });

    test('isResearchOnly defaults to false', () {
      const model = ModelInfo(
        id: 'test',
        displayName: 'Test',
        description: 'Test',
        provider: ModelProvider.cloud,
      );
      expect(model.isResearchOnly, isFalse);
      expect(model.licenseName, isNull);
    });

    test('isResearchOnly can be set to true', () {
      const model = ModelInfo(
        id: 'test',
        displayName: 'Test',
        description: 'Test',
        provider: ModelProvider.offline,
        isResearchOnly: true,
        licenseName: 'Test License',
      );
      expect(model.isResearchOnly, isTrue);
      expect(model.licenseName, 'Test License');
    });

    group('estimatedSizeFormatted', () {
      test('returns empty string when estimatedSizeBytes is null', () {
        const model = ModelInfo(
          id: 'test',
          displayName: 'Test',
          description: 'Test',
          provider: ModelProvider.offline,
        );
        expect(model.estimatedSizeFormatted, '');
      });

      test('formats bytes less than 1 GB as MB', () {
        const model = ModelInfo(
          id: 'test',
          displayName: 'Test',
          description: 'Test',
          provider: ModelProvider.offline,
          estimatedSizeBytes: 400 * 1024 * 1024, // 400 MB
        );
        expect(model.estimatedSizeFormatted, '400 MB');
      });

      test('formats bytes >= 1 GB as GB with one decimal', () {
        const model = ModelInfo(
          id: 'test',
          displayName: 'Test',
          description: 'Test',
          provider: ModelProvider.offline,
          estimatedSizeBytes: 1024 * 1024 * 1024, // 1.0 GB
        );
        expect(model.estimatedSizeFormatted, '1.0 GB');
      });

      test('formats 1.8 GB correctly', () {
        final model = ModelInfo(
          id: 'test',
          displayName: 'Test',
          description: 'Test',
          provider: ModelProvider.offline,
          estimatedSizeBytes: (1.8 * 1024 * 1024 * 1024).toInt(),
        );
        expect(model.estimatedSizeFormatted, '1.8 GB');
      });

      test('formats exactly 1 MB correctly', () {
        const model = ModelInfo(
          id: 'test',
          displayName: 'Test',
          description: 'Test',
          provider: ModelProvider.offline,
          estimatedSizeBytes: 1 * 1024 * 1024,
        );
        expect(model.estimatedSizeFormatted, '1 MB');
      });

      test('formats small size as 0 MB', () {
        const model = ModelInfo(
          id: 'test',
          displayName: 'Test',
          description: 'Test',
          provider: ModelProvider.offline,
          estimatedSizeBytes: 500 * 1024, // 500 KB
        );
        expect(model.estimatedSizeFormatted, '0 MB');
      });
    });
  });

  group('OfflineModelState', () {
    test('defaults to notDownloaded with 0 progress', () {
      final state = OfflineModelState(modelId: 'test');
      expect(state.downloadState, ModelDownloadState.notDownloaded);
      expect(state.downloadProgress, 0.0);
      expect(state.diskUsageBytes, isNull);
      expect(state.errorMessage, isNull);
    });

    test('copyWith creates new instance with updated fields', () {
      final state = OfflineModelState(modelId: 'test');
      final updated = state.copyWith(
        downloadState: ModelDownloadState.downloading,
        downloadProgress: 0.5,
      );
      expect(updated.modelId, 'test');
      expect(updated.downloadState, ModelDownloadState.downloading);
      expect(updated.downloadProgress, 0.5);
      expect(updated.diskUsageBytes, isNull);
    });

    test('copyWith preserves unchanged fields', () {
      final state = OfflineModelState(
        modelId: 'test',
        downloadState: ModelDownloadState.downloaded,
        downloadProgress: 1.0,
        diskUsageBytes: 12345,
      );
      final updated = state.copyWith(errorMessage: 'oops');
      expect(updated.downloadState, ModelDownloadState.downloaded);
      expect(updated.downloadProgress, 1.0);
      expect(updated.diskUsageBytes, 12345);
      expect(updated.errorMessage, 'oops');
    });

    group('diskUsageFormatted', () {
      test('returns empty string when diskUsageBytes is null', () {
        final state = OfflineModelState(modelId: 'test');
        expect(state.diskUsageFormatted, '');
      });

      test('formats bytes < 1 GB as MB', () {
        final state = OfflineModelState(
          modelId: 'test',
          diskUsageBytes: 412 * 1024 * 1024,
        );
        expect(state.diskUsageFormatted, '412 MB');
      });

      test('formats bytes >= 1 GB as GB with two decimals', () {
        final state = OfflineModelState(
          modelId: 'test',
          diskUsageBytes: (1.85 * 1024 * 1024 * 1024).toInt(),
        );
        expect(state.diskUsageFormatted, '1.85 GB');
      });

      test('formats exactly 1 GB', () {
        final state = OfflineModelState(
          modelId: 'test',
          diskUsageBytes: 1024 * 1024 * 1024,
        );
        expect(state.diskUsageFormatted, '1.00 GB');
      });

      test('formats 0 bytes', () {
        final state = OfflineModelState(
          modelId: 'test',
          diskUsageBytes: 0,
        );
        expect(state.diskUsageFormatted, '0 MB');
      });
    });

    test('state transitions: notDownloaded -> downloading -> downloaded', () {
      final state = OfflineModelState(modelId: 'test');
      expect(state.downloadState, ModelDownloadState.notDownloaded);

      state.downloadState = ModelDownloadState.downloading;
      state.downloadProgress = 0.5;
      expect(state.downloadState, ModelDownloadState.downloading);
      expect(state.downloadProgress, 0.5);

      state.downloadState = ModelDownloadState.downloaded;
      state.downloadProgress = 1.0;
      state.diskUsageBytes = 400 * 1024 * 1024;
      expect(state.downloadState, ModelDownloadState.downloaded);
      expect(state.diskUsageBytes, 400 * 1024 * 1024);
    });

    test('state transitions: downloading -> error', () {
      final state = OfflineModelState(
        modelId: 'test',
        downloadState: ModelDownloadState.downloading,
        downloadProgress: 0.3,
      );

      state.downloadState = ModelDownloadState.error;
      state.errorMessage = 'Network timeout';
      expect(state.downloadState, ModelDownloadState.error);
      expect(state.errorMessage, 'Network timeout');
    });
  });

  group('ModelRegistry — cloud models', () {
    test('has 4 cloud models', () {
      expect(ModelRegistry.cloudModels.length, 4);
    });

    test('all cloud models have cloud provider', () {
      for (final model in ModelRegistry.cloudModels) {
        expect(model.provider, ModelProvider.cloud);
        expect(model.isCloud, isTrue);
        expect(model.isOffline, isFalse);
      }
    });

    test('all cloud models have apiModelId', () {
      for (final model in ModelRegistry.cloudModels) {
        expect(model.apiModelId, isNotNull);
        expect(model.apiModelId, isNotEmpty);
      }
    });

    test('no cloud model has huggingFaceRepo', () {
      for (final model in ModelRegistry.cloudModels) {
        expect(model.huggingFaceRepo, isNull);
      }
    });

    test('no cloud model has estimatedSizeBytes', () {
      for (final model in ModelRegistry.cloudModels) {
        expect(model.estimatedSizeBytes, isNull);
      }
    });

    test('no cloud model is research-only', () {
      for (final model in ModelRegistry.cloudModels) {
        expect(model.isResearchOnly, isFalse);
      }
    });

    test('cloud model IDs are correct', () {
      final ids = ModelRegistry.cloudModels.map((m) => m.id).toList();
      expect(ids, ['auto', 'opus', 'sonnet', 'haiku']);
    });

    test('auto model description mentions Opus and Haiku', () {
      expect(ModelRegistry.auto.description, contains('Opus'));
      expect(ModelRegistry.auto.description, contains('Haiku'));
    });
  });

  group('ModelRegistry — offline models', () {
    test('has 3 offline models', () {
      expect(ModelRegistry.offlineModels.length, 3);
    });

    test('all offline models have offline provider', () {
      for (final model in ModelRegistry.offlineModels) {
        expect(model.provider, ModelProvider.offline);
        expect(model.isOffline, isTrue);
        expect(model.isCloud, isFalse);
      }
    });

    test('all offline models have huggingFaceRepo', () {
      for (final model in ModelRegistry.offlineModels) {
        expect(model.huggingFaceRepo, isNotNull);
        expect(model.huggingFaceRepo, isNotEmpty);
      }
    });

    test('all offline models have mlcModelLib', () {
      for (final model in ModelRegistry.offlineModels) {
        expect(model.mlcModelLib, isNotNull);
        expect(model.mlcModelLib, isNotEmpty);
      }
    });

    test('all offline models have estimatedSizeBytes', () {
      for (final model in ModelRegistry.offlineModels) {
        expect(model.estimatedSizeBytes, isNotNull);
        expect(model.estimatedSizeBytes, greaterThan(0));
      }
    });

    test('no offline model has apiModelId', () {
      for (final model in ModelRegistry.offlineModels) {
        expect(model.apiModelId, isNull);
      }
    });

    test('offline model IDs are correct', () {
      final ids = ModelRegistry.offlineModels.map((m) => m.id).toList();
      expect(ids, ['qwen2.5-coder-0.5b', 'qwen2.5-coder-1.5b', 'qwen2.5-coder-3b']);
    });

    test('offline models are sorted by size', () {
      final sizes = ModelRegistry.offlineModels
          .map((m) => m.estimatedSizeBytes!)
          .toList();
      for (int i = 1; i < sizes.length; i++) {
        expect(sizes[i], greaterThan(sizes[i - 1]),
            reason: 'Models should be sorted by size ascending');
      }
    });

    test('qwen05b estimated size is ~400 MB', () {
      final bytes = ModelRegistry.qwen05b.estimatedSizeBytes!;
      final mb = bytes / (1024 * 1024);
      expect(mb, closeTo(400, 1));
    });

    test('qwen15b estimated size is ~1.0 GB', () {
      final bytes = ModelRegistry.qwen15b.estimatedSizeBytes!;
      final gb = bytes / (1024 * 1024 * 1024);
      expect(gb, closeTo(1.0, 0.01));
    });

    test('qwen3b estimated size is ~1.8 GB', () {
      final bytes = ModelRegistry.qwen3b.estimatedSizeBytes!;
      final gb = bytes / (1024 * 1024 * 1024);
      expect(gb, closeTo(1.8, 0.01));
    });

    test('huggingFaceRepo contains alexandertaboriskiy prefix', () {
      for (final model in ModelRegistry.offlineModels) {
        expect(model.huggingFaceRepo, startsWith('alexandertaboriskiy/'));
      }
    });

    test('all offline models have a licenseName', () {
      for (final model in ModelRegistry.offlineModels) {
        expect(model.licenseName, isNotNull);
        expect(model.licenseName, isNotEmpty);
      }
    });

    test('qwen05b and qwen15b are Apache-2.0 licensed', () {
      expect(ModelRegistry.qwen05b.licenseName, 'Apache-2.0');
      expect(ModelRegistry.qwen15b.licenseName, 'Apache-2.0');
    });

    test('qwen05b and qwen15b are not research-only', () {
      expect(ModelRegistry.qwen05b.isResearchOnly, isFalse);
      expect(ModelRegistry.qwen15b.isResearchOnly, isFalse);
    });

    test('qwen3b is research-only with Qwen Research License', () {
      expect(ModelRegistry.qwen3b.isResearchOnly, isTrue);
      expect(ModelRegistry.qwen3b.licenseName, 'Qwen Research License');
    });
  });

  group('ModelRegistry — allModels', () {
    test('contains all cloud and offline models', () {
      expect(
        ModelRegistry.allModels.length,
        ModelRegistry.cloudModels.length + ModelRegistry.offlineModels.length,
      );
    });

    test('no duplicate IDs', () {
      final ids = ModelRegistry.allModels.map((m) => m.id).toSet();
      expect(ids.length, ModelRegistry.allModels.length,
          reason: 'All model IDs should be unique');
    });

    test('all models have non-empty id', () {
      for (final model in ModelRegistry.allModels) {
        expect(model.id, isNotEmpty);
      }
    });

    test('all models have non-empty displayName', () {
      for (final model in ModelRegistry.allModels) {
        expect(model.displayName, isNotEmpty);
      }
    });

    test('all models have non-empty description', () {
      for (final model in ModelRegistry.allModels) {
        expect(model.description, isNotEmpty);
      }
    });
  });

  group('ModelRegistry.getById', () {
    test('returns correct cloud model for each cloud ID', () {
      expect(ModelRegistry.getById('auto')?.id, 'auto');
      expect(ModelRegistry.getById('opus')?.id, 'opus');
      expect(ModelRegistry.getById('sonnet')?.id, 'sonnet');
      expect(ModelRegistry.getById('haiku')?.id, 'haiku');
    });

    test('returns correct offline model for each offline ID', () {
      expect(ModelRegistry.getById('qwen2.5-coder-0.5b')?.id, 'qwen2.5-coder-0.5b');
      expect(ModelRegistry.getById('qwen2.5-coder-1.5b')?.id, 'qwen2.5-coder-1.5b');
      expect(ModelRegistry.getById('qwen2.5-coder-3b')?.id, 'qwen2.5-coder-3b');
    });

    test('returns null for unknown ID', () {
      expect(ModelRegistry.getById('unknown'), isNull);
      expect(ModelRegistry.getById(''), isNull);
      expect(ModelRegistry.getById('gpt-4'), isNull);
    });

    test('returns correct provider for looked-up model', () {
      expect(ModelRegistry.getById('opus')?.provider, ModelProvider.cloud);
      expect(ModelRegistry.getById('qwen2.5-coder-0.5b')?.provider, ModelProvider.offline);
    });

    test('is case-sensitive', () {
      expect(ModelRegistry.getById('Auto'), isNull);
      expect(ModelRegistry.getById('OPUS'), isNull);
      expect(ModelRegistry.getById('Qwen2.5-Coder-0.5B'), isNull);
    });
  });

  group('ModelRegistry.getModelDirName', () {
    test('returns modelId as directory name', () {
      expect(ModelRegistry.getModelDirName('qwen2.5-coder-0.5b'), 'qwen2.5-coder-0.5b');
      expect(ModelRegistry.getModelDirName('qwen2.5-coder-3b'), 'qwen2.5-coder-3b');
    });

    test('handles arbitrary input', () {
      expect(ModelRegistry.getModelDirName('anything'), 'anything');
      expect(ModelRegistry.getModelDirName(''), '');
    });
  });

  group('ModelInfo — estimatedSizeFormatted edge cases', () {
    test('estimatedSizeBytes = 0 returns 0 MB', () {
      const model = ModelInfo(
        id: 'test',
        displayName: 'Test',
        description: 'Test',
        provider: ModelProvider.offline,
        estimatedSizeBytes: 0,
      );
      expect(model.estimatedSizeFormatted, '0 MB');
    });

    test('estimatedSizeBytes = 1 returns 0 MB', () {
      const model = ModelInfo(
        id: 'test',
        displayName: 'Test',
        description: 'Test',
        provider: ModelProvider.offline,
        estimatedSizeBytes: 1,
      );
      expect(model.estimatedSizeFormatted, '0 MB');
    });

    test('very large: 10 GB returns 10.0 GB', () {
      const tenGB = 10 * 1024 * 1024 * 1024;
      const model = ModelInfo(
        id: 'test',
        displayName: 'Test',
        description: 'Test',
        provider: ModelProvider.offline,
        estimatedSizeBytes: tenGB,
      );
      expect(model.estimatedSizeFormatted, '10.0 GB');
    });

    test('exactly at GB boundary minus 1 returns MB', () {
      const justUnderGB = 1024 * 1024 * 1024 - 1;
      const model = ModelInfo(
        id: 'test',
        displayName: 'Test',
        description: 'Test',
        provider: ModelProvider.offline,
        estimatedSizeBytes: justUnderGB,
      );
      // Should be formatted as MB since it's less than 1 GB
      expect(model.estimatedSizeFormatted, contains('MB'));
      expect(model.estimatedSizeFormatted, isNot(contains('GB')));
      // 1024*1024*1024 - 1 bytes = 1023.999... MB => rounds to 1024 MB
      expect(model.estimatedSizeFormatted, '1024 MB');
    });

    test('negative value does not crash', () {
      const model = ModelInfo(
        id: 'test',
        displayName: 'Test',
        description: 'Test',
        provider: ModelProvider.offline,
        estimatedSizeBytes: -1,
      );
      // Should not throw — just returns some string
      expect(() => model.estimatedSizeFormatted, returnsNormally);
      expect(model.estimatedSizeFormatted, isA<String>());
    });
  });

  group('OfflineModelState — copyWith deeper tests', () {
    test('copyWith with all null args preserves all fields', () {
      final state = OfflineModelState(
        modelId: 'test-model',
        downloadState: ModelDownloadState.downloading,
        downloadProgress: 0.75,
        diskUsageBytes: 999999,
        errorMessage: 'some error',
      );
      final copied = state.copyWith();
      expect(copied.modelId, 'test-model');
      expect(copied.downloadState, ModelDownloadState.downloading);
      expect(copied.downloadProgress, 0.75);
      expect(copied.diskUsageBytes, 999999);
      expect(copied.errorMessage, 'some error');
    });

    test('copyWith cannot reset errorMessage to null (uses ?? operator)', () {
      // This documents a known limitation: copyWith uses ?? so passing null
      // for errorMessage keeps the old value instead of resetting to null.
      final state = OfflineModelState(
        modelId: 'test-model',
        errorMessage: 'existing error',
      );
      final copied = state.copyWith(errorMessage: null);
      // Because of ??, null falls through to the existing value
      expect(copied.errorMessage, 'existing error',
          reason: 'copyWith uses ?? so null does not clear existing value');
    });

    test('copyWith on downloadProgress from 0.5 to 0.0', () {
      final state = OfflineModelState(
        modelId: 'test',
        downloadProgress: 0.5,
      );
      // 0.0 is falsy-ish for ??, but in Dart the ?? operator only checks
      // for null, not 0.0. So passing 0.0 should work.
      final copied = state.copyWith(downloadProgress: 0.0);
      expect(copied.downloadProgress, 0.0);
    });
  });

  group('ModelRegistry — HuggingFace repo URLs', () {
    test('all offline model repos start with alexandertaboriskiy/', () {
      for (final model in ModelRegistry.offlineModels) {
        expect(model.huggingFaceRepo, startsWith('alexandertaboriskiy/'),
            reason: '${model.id} repo should start with alexandertaboriskiy/');
      }
    });

    test('all offline model repos contain q4f16_0-MLC', () {
      for (final model in ModelRegistry.offlineModels) {
        expect(model.huggingFaceRepo, contains('q4f16_0-MLC'),
            reason: '${model.id} repo should contain q4f16_0-MLC');
      }
    });

    test('all offline model repos contain display-relevant model name', () {
      // Each repo should contain the Qwen model variant name
      expect(ModelRegistry.qwen05b.huggingFaceRepo, contains('Qwen2.5-Coder-0.5B'));
      expect(ModelRegistry.qwen15b.huggingFaceRepo, contains('Qwen2.5-Coder-1.5B'));
      expect(ModelRegistry.qwen3b.huggingFaceRepo, contains('Qwen2.5-Coder-3B'));
    });
  });

  group('ModelRegistry — mlcModelLib consistency', () {
    test('all mlcModelLib values start with qwen2_q4f16_0_', () {
      for (final model in ModelRegistry.offlineModels) {
        expect(model.mlcModelLib, startsWith('qwen2_q4f16_0_'),
            reason: '${model.id} mlcModelLib should start with qwen2_q4f16_0_');
      }
    });

    test('all mlcModelLib values are unique', () {
      final libs = ModelRegistry.offlineModels
          .map((m) => m.mlcModelLib)
          .toSet();
      expect(libs.length, ModelRegistry.offlineModels.length,
          reason: 'Each offline model must have a unique mlcModelLib');
    });

    test('mlcModelLib is at least 30 chars (prefix + 32-char hex hash)', () {
      for (final model in ModelRegistry.offlineModels) {
        expect(model.mlcModelLib!.length, greaterThanOrEqualTo(30),
            reason: '${model.id} mlcModelLib should be at least 30 chars '
                '(prefix "qwen2_q4f16_0_" = 14 chars + 32-char hash = 46)');
      }
    });
  });

  group('ModelRegistry — allModels ordering', () {
    test('cloud models come before offline models in allModels', () {
      final allModels = ModelRegistry.allModels;
      int lastCloudIndex = -1;
      int firstOfflineIndex = allModels.length;

      for (int i = 0; i < allModels.length; i++) {
        if (allModels[i].isCloud) {
          lastCloudIndex = i;
        }
        if (allModels[i].isOffline && i < firstOfflineIndex) {
          firstOfflineIndex = i;
        }
      }

      expect(lastCloudIndex, lessThan(firstOfflineIndex),
          reason: 'All cloud models should appear before any offline model');
    });
  });

  group('ModelRegistry.getById — stress tests', () {
    test('very long string input returns null', () {
      final longId = 'a' * 10000;
      expect(ModelRegistry.getById(longId), isNull);
    });

    test('special characters in input return null', () {
      expect(ModelRegistry.getById('!@#\$%^&*()'), isNull);
      expect(ModelRegistry.getById('<script>alert("xss")</script>'), isNull);
      expect(ModelRegistry.getById('model\x00id'), isNull);
      expect(ModelRegistry.getById('model\nid'), isNull);
      expect(ModelRegistry.getById('model\tid'), isNull);
      expect(ModelRegistry.getById('qwen2.5-coder-0.5b; DROP TABLE models;'), isNull);
    });

    test('substring of valid ID returns null', () {
      // 'qwen2.5' is a substring of 'qwen2.5-coder-0.5b' but not a valid ID
      expect(ModelRegistry.getById('qwen2.5'), isNull);
    });

    test('prefix of valid ID returns null', () {
      // 'qwen2.5-coder-0' is a prefix of 'qwen2.5-coder-0.5b' but not a valid ID
      expect(ModelRegistry.getById('qwen2.5-coder-0'), isNull);
    });
  });
}
