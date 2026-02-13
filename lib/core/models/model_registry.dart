/// Model registry for cloud and offline (on-device) models.
///
/// Cloud models are Claude API models. Offline models are local LLMs
/// that run on-device via MLC LLM (Qwen2.5-Coder family).

enum ModelProvider { cloud, offline }

enum ModelDownloadState { notDownloaded, downloading, downloaded, error }

class ModelInfo {
  final String id;
  final String displayName;
  final String description;
  final ModelProvider provider;
  final String? huggingFaceRepo;
  final String? mlcModelLib;
  final int? estimatedSizeBytes;
  final String? apiModelId;
  final bool isResearchOnly;
  final String? licenseName;

  const ModelInfo({
    required this.id,
    required this.displayName,
    required this.description,
    required this.provider,
    this.huggingFaceRepo,
    this.mlcModelLib,
    this.estimatedSizeBytes,
    this.apiModelId,
    this.isResearchOnly = false,
    this.licenseName,
  });

  bool get isOffline => provider == ModelProvider.offline;
  bool get isCloud => provider == ModelProvider.cloud;

  /// Human-readable estimated size (e.g. "400 MB", "1.0 GB").
  String get estimatedSizeFormatted {
    if (estimatedSizeBytes == null) return '';
    final bytes = estimatedSizeBytes!;
    if (bytes >= 1024 * 1024 * 1024) {
      final gb = bytes / (1024 * 1024 * 1024);
      return '${gb.toStringAsFixed(1)} GB';
    }
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(0)} MB';
  }
}

class OfflineModelState {
  final String modelId;
  ModelDownloadState downloadState;
  double downloadProgress;
  int? diskUsageBytes;
  String? errorMessage;

  OfflineModelState({
    required this.modelId,
    this.downloadState = ModelDownloadState.notDownloaded,
    this.downloadProgress = 0.0,
    this.diskUsageBytes,
    this.errorMessage,
  });

  /// Human-readable disk usage (e.g. "412 MB", "1.85 GB").
  String get diskUsageFormatted {
    if (diskUsageBytes == null) return '';
    final bytes = diskUsageBytes!;
    if (bytes >= 1024 * 1024 * 1024) {
      final gb = bytes / (1024 * 1024 * 1024);
      return '${gb.toStringAsFixed(2)} GB';
    }
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(0)} MB';
  }

  OfflineModelState copyWith({
    ModelDownloadState? downloadState,
    double? downloadProgress,
    int? diskUsageBytes,
    String? errorMessage,
  }) {
    return OfflineModelState(
      modelId: modelId,
      downloadState: downloadState ?? this.downloadState,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      diskUsageBytes: diskUsageBytes ?? this.diskUsageBytes,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class ModelRegistry {
  ModelRegistry._();

  // -- Cloud models --

  static const auto = ModelInfo(
    id: 'auto',
    displayName: 'Auto',
    description: 'Opus by default, Haiku when budget is low',
    provider: ModelProvider.cloud,
    apiModelId: 'auto',
  );

  static const opus = ModelInfo(
    id: 'opus',
    displayName: 'Opus',
    description: 'Best quality, highest cost',
    provider: ModelProvider.cloud,
    apiModelId: 'claude-opus-4-20250514',
  );

  static const sonnet = ModelInfo(
    id: 'sonnet',
    displayName: 'Sonnet',
    description: 'Good quality, moderate cost',
    provider: ModelProvider.cloud,
    apiModelId: 'claude-sonnet-4-5-20250929',
  );

  static const haiku = ModelInfo(
    id: 'haiku',
    displayName: 'Haiku',
    description: 'Faster, lower cost',
    provider: ModelProvider.cloud,
    apiModelId: 'claude-haiku-4-5-20251001',
  );

  static const cloudModels = [auto, opus, sonnet, haiku];

  // -- Offline models (MLC LLM quantized) --

  static const qwen05b = ModelInfo(
    id: 'qwen2.5-coder-0.5b',
    displayName: 'Qwen 0.5B Coder',
    description: 'Smallest, fastest — good for simple tasks',
    provider: ModelProvider.offline,
    huggingFaceRepo: 'alexandertaboriskiy/Qwen2.5-Coder-0.5B-Instruct-q4f16_0-MLC',
    mlcModelLib: 'qwen2_q4f16_0_ce81ef8767dfb3f843c79deb0b3f66fc',
    estimatedSizeBytes: 400 * 1024 * 1024, // ~400 MB
    licenseName: 'Apache-2.0',
  );

  static const qwen15b = ModelInfo(
    id: 'qwen2.5-coder-1.5b',
    displayName: 'Qwen 1.5B Coder',
    description: 'Balanced speed and quality',
    provider: ModelProvider.offline,
    huggingFaceRepo: 'alexandertaboriskiy/Qwen2.5-Coder-1.5B-Instruct-q4f16_0-MLC',
    mlcModelLib: 'qwen2_q4f16_0_1be22ffdc6429c5019af9af8dae22086',
    estimatedSizeBytes: 1024 * 1024 * 1024, // ~1.0 GB
    licenseName: 'Apache-2.0',
  );

  static const qwen3b = ModelInfo(
    id: 'qwen2.5-coder-3b',
    displayName: 'Qwen 3B Coder',
    description: 'Best offline quality, uses more storage',
    provider: ModelProvider.offline,
    huggingFaceRepo: 'alexandertaboriskiy/Qwen2.5-Coder-3B-Instruct-q4f16_0-MLC',
    mlcModelLib: 'qwen2_q4f16_0_ecc0cde57625a5817018e8d547361bb3',
    estimatedSizeBytes: 1932735283, // ~1.8 GB (1.8 * 1024^3)
    isResearchOnly: true,
    licenseName: 'Qwen Research License',
  );

  static const ministral3b = ModelInfo(
    id: 'ministral-3-3b',
    displayName: 'Ministral 3B',
    description: 'Newest, edge-optimized — native tool calling',
    provider: ModelProvider.offline,
    huggingFaceRepo: 'alexandertaboriskiy/Ministral-3-3B-Instruct-2512-q4f16_0-MLC',
    mlcModelLib: 'ministral3_q4f16_0_68e08feb72d08c3826f6a0b3623b81fc',
    estimatedSizeBytes: 1946443381, // 1.95 GB
    licenseName: 'Apache-2.0',
  );

  static const qwen3_4b = ModelInfo(
    id: 'qwen3-4b',
    displayName: 'Qwen3 4B',
    description: 'Best quality, /think mode — strongest tool use',
    provider: ModelProvider.offline,
    huggingFaceRepo: 'alexandertaboriskiy/Qwen3-4B-q4f16_0-MLC',
    mlcModelLib: 'qwen3_q4f16_0_744427a6c2d881a41e79d0bfb2a540dc',
    estimatedSizeBytes: 2278983910, // 2.28 GB
    licenseName: 'Apache-2.0',
  );

  static const offlineModels = [qwen05b, qwen15b, qwen3b, ministral3b, qwen3_4b];

  static List<ModelInfo> get allModels => [...cloudModels, ...offlineModels];

  /// Look up a model by its ID. Returns `null` if not found.
  static ModelInfo? getById(String id) {
    for (final model in allModels) {
      if (model.id == id) return model;
    }
    return null;
  }

  /// The directory name for a given offline model inside `mlc_models/`.
  static String getModelDirName(String modelId) => modelId;
}
