import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../models/model_registry.dart';
import 'storage_service.dart';

/// Inference load state for the on-device model.
enum ModelLoadState { unloaded, loading, loaded, generating, error }

/// Service for managing on-device LLM models.
///
/// Phase 1: state management, disk scanning, persistence.
/// Phase 2: download from HuggingFace with progress, cancel, disk validation.
/// Phase 3: load, generate via MLC LLM engine.
class LocalLLMService {
  static final LocalLLMService instance = LocalLLMService._();

  static const _downloadMethodChannel =
      MethodChannel('ai.navixmind/model_download');
  static const _downloadEventChannel =
      EventChannel('ai.navixmind/model_download_events');
  static const _inferenceMethodChannel =
      MethodChannel('ai.navixmind/mlc_inference');

  LocalLLMService._();

  /// Allow injecting custom dependencies for testing.
  @visibleForTesting
  factory LocalLLMService.forTesting({
    required Directory modelsDir,
    required Future<String?> Function() getPersistedStates,
    required Future<void> Function(String) setPersistedStates,
    Future<void> Function(String modelId, String repoId, String destDir)?
        startDownload,
    Future<void> Function(String modelId)? cancelDownload,
    Future<int> Function()? getAvailableSpace,
    Stream<String>? downloadEventStream,
    Future<bool> Function(String modelId, String modelPath, String modelLib)?
        loadModelOverride,
    Future<String> Function(String messagesJson, String? toolsJson, int maxTokens)?
        generateOverride,
    Future<void> Function()? unloadModelOverride,
  }) {
    return LocalLLMService._forTesting(
      modelsDir,
      getPersistedStates,
      setPersistedStates,
      startDownload,
      cancelDownload,
      getAvailableSpace,
      downloadEventStream,
      loadModelOverride,
      generateOverride,
      unloadModelOverride,
    );
  }

  LocalLLMService._forTesting(
    this._modelsDirOverride,
    this._getPersistedStatesOverride,
    this._setPersistedStatesOverride,
    this._startDownloadOverride,
    this._cancelDownloadOverride,
    this._getAvailableSpaceOverride,
    this._downloadEventStreamOverride,
    this._loadModelOverride,
    this._generateOverride,
    this._unloadModelOverride,
  );

  Directory? _modelsDirOverride;
  Future<String?> Function()? _getPersistedStatesOverride;
  Future<void> Function(String)? _setPersistedStatesOverride;
  Future<void> Function(String, String, String)? _startDownloadOverride;
  Future<void> Function(String)? _cancelDownloadOverride;
  Future<int> Function()? _getAvailableSpaceOverride;
  Stream<String>? _downloadEventStreamOverride;
  Future<bool> Function(String, String, String)? _loadModelOverride;
  Future<String> Function(String, String?, int)? _generateOverride;
  Future<void> Function()? _unloadModelOverride;

  final Map<String, OfflineModelState> _states = {};
  String? _loadedModelId;
  ModelLoadState _loadState = ModelLoadState.unloaded;
  String? _loadError;
  StreamSubscription<dynamic>? _downloadEventSubscription;

  final _stateController =
      StreamController<Map<String, OfflineModelState>>.broadcast();
  final _loadStateController = StreamController<ModelLoadState>.broadcast();

  /// Stream of offline model states. Emits whenever any model's state changes.
  Stream<Map<String, OfflineModelState>> get stateStream =>
      _stateController.stream;

  /// Stream of model load state changes for UI indicators.
  Stream<ModelLoadState> get loadStateStream => _loadStateController.stream;

  /// Current model load state.
  ModelLoadState get loadState => _loadState;

  /// Current load error message, if any.
  String? get loadError => _loadError;

  /// Current snapshot of all offline model states.
  Map<String, OfflineModelState> get modelStates =>
      Map.unmodifiable(_states);

  /// The currently loaded model ID, or null if none loaded.
  String? get loadedModelId => _loadedModelId;

  /// Initialize the service: restore persisted state and scan disk.
  Future<void> initialize() async {
    // Initialize all offline models with default state
    for (final model in ModelRegistry.offlineModels) {
      _states[model.id] = OfflineModelState(modelId: model.id);
    }

    // Restore persisted state
    await _restorePersistedState();

    // Scan filesystem for actually-downloaded models
    await _scanDownloadedModels();

    _emitState();
  }

  /// Get the base directory for all MLC model files.
  Future<Directory> getModelsDirectory() async {
    if (_modelsDirOverride != null) return _modelsDirOverride!;
    final appDir = await getApplicationDocumentsDirectory();
    return Directory('${appDir.path}/mlc_models');
  }

  /// Get the directory for a specific model.
  Future<Directory> getModelDirectory(String modelId) async {
    final baseDir = await getModelsDirectory();
    return Directory(
        '${baseDir.path}/${ModelRegistry.getModelDirName(modelId)}');
  }

  /// Check whether a model's files are fully downloaded.
  ///
  /// A model is considered downloaded only if the directory exists AND contains
  /// the ndarray-cache.json (or tensor-cache.json) manifest file. This file
  /// is required by the TVM runtime — loading without it causes a fatal crash.
  Future<bool> isModelDownloaded(String modelId) async {
    final dir = await getModelDirectory(modelId);
    if (!await dir.exists()) return false;
    // TVM requires the tensor cache manifest to load the model.
    // Check for both possible names (varies by MLC LLM version).
    final ndarrayCache = File('${dir.path}/ndarray-cache.json');
    final tensorCache = File('${dir.path}/tensor-cache.json');
    return await ndarrayCache.exists() || await tensorCache.exists();
  }

  /// Calculate the actual disk usage of a model's directory in bytes.
  Future<int> getModelDiskUsage(String modelId) async {
    final dir = await getModelDirectory(modelId);
    if (!await dir.exists()) return 0;
    int total = 0;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        total += await entity.length();
      }
    }
    return total;
  }

  /// Download a model from HuggingFace.
  Future<void> downloadModel(String modelId) async {
    final model = ModelRegistry.getById(modelId);
    if (model == null || !model.isOffline) {
      throw ArgumentError('Invalid offline model ID: $modelId');
    }
    if (model.huggingFaceRepo == null) {
      throw ArgumentError('Model $modelId has no HuggingFace repo configured');
    }

    final currentState = _states[modelId];
    if (currentState?.downloadState == ModelDownloadState.downloading) return;
    if (currentState?.downloadState == ModelDownloadState.downloaded) return;

    // Pre-download disk space check
    final estimatedSize = model.estimatedSizeBytes ?? 0;
    if (estimatedSize > 0) {
      try {
        final availableBytes = await _getAvailableSpace();
        final requiredBytes = (estimatedSize * 1.1).toInt();
        if (availableBytes < requiredBytes) {
          final needMB = requiredBytes ~/ (1024 * 1024);
          final haveMB = availableBytes ~/ (1024 * 1024);
          _states[modelId] = OfflineModelState(
            modelId: modelId,
            downloadState: ModelDownloadState.error,
            errorMessage: 'Not enough disk space. Need ${needMB}MB, have ${haveMB}MB',
          );
          await _persistState();
          _emitState();
          return;
        }
      } catch (e) {
        // If we can't check space, proceed anyway — Kotlin will also check
      }
    }

    // Set downloading state
    _states[modelId] = OfflineModelState(
      modelId: modelId,
      downloadState: ModelDownloadState.downloading,
      downloadProgress: 0.0,
    );
    _emitState();

    // Ensure event listener is active
    _ensureDownloadEventListener();

    // Start download via MethodChannel
    final destDir = await getModelDirectory(modelId);
    try {
      await _startDownload(modelId, model.huggingFaceRepo!, destDir.path);
    } on PlatformException catch (e) {
      _states[modelId] = OfflineModelState(
        modelId: modelId,
        downloadState: ModelDownloadState.error,
        errorMessage: e.message ?? 'Download failed',
      );
      await _persistState();
      _emitState();
    }
  }

  /// Cancel an in-progress download.
  Future<void> cancelDownload(String modelId) async {
    final currentState = _states[modelId];
    if (currentState?.downloadState != ModelDownloadState.downloading) return;

    try {
      await _cancelDownload(modelId);
    } catch (_) {
      // Best effort
    }

    _states[modelId] = OfflineModelState(modelId: modelId);
    await _persistState();
    _emitState();
  }

  /// Delete a downloaded model from disk.
  Future<void> deleteModel(String modelId) async {
    final dir = await getModelDirectory(modelId);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    _states[modelId] = OfflineModelState(modelId: modelId);
    await _persistState();
    _emitState();
  }

  /// Load a model into GPU memory for inference.
  ///
  /// Takes 10-30s depending on model size. Emits state changes via
  /// [loadStateStream] so the UI can show loading indicators.
  Future<void> loadModel(String modelId) async {
    final model = ModelRegistry.getById(modelId);
    if (model == null || !model.isOffline) {
      throw ArgumentError('Invalid offline model ID: $modelId');
    }

    // Already loaded?
    if (_loadedModelId == modelId && _loadState == ModelLoadState.loaded) {
      return;
    }

    // Unload previous model if different
    if (_loadedModelId != null && _loadedModelId != modelId) {
      await unloadModel();
    }

    _updateLoadState(ModelLoadState.loading);

    try {
      // Verify model is fully downloaded before loading.
      // Loading an incomplete model crashes the TVM runtime (fatal abort).
      final downloaded = await isModelDownloaded(modelId);
      if (!downloaded) {
        throw PlatformException(
          code: 'MODEL_NOT_READY',
          message: 'Model $modelId is not fully downloaded. '
              'Please wait for the download to complete.',
        );
      }

      final modelDir = await getModelDirectory(modelId);
      final modelLib = model.mlcModelLib ?? modelId;

      if (_loadModelOverride != null) {
        await _loadModelOverride!(modelId, modelDir.path, modelLib);
      } else {
        await _inferenceMethodChannel.invokeMethod('loadModel', {
          'modelId': modelId,
          'modelPath': modelDir.path,
          'modelLib': modelLib,
        });
      }

      _loadedModelId = modelId;
      _loadError = null;
      _updateLoadState(ModelLoadState.loaded);
      debugPrint('[LocalLLM] Model $modelId loaded');
    } on PlatformException catch (e) {
      _loadedModelId = null;
      _loadError = e.message ?? 'Failed to load model';
      _updateLoadState(ModelLoadState.error);
      debugPrint('[LocalLLM] Load failed: ${e.message}');
      rethrow;
    } catch (e) {
      _loadedModelId = null;
      _loadError = e.toString();
      _updateLoadState(ModelLoadState.error);
      debugPrint('[LocalLLM] Load failed: $e');
      rethrow;
    }
  }

  /// Unload the currently loaded model from GPU memory.
  Future<void> unloadModel() async {
    if (_loadedModelId == null) return;

    try {
      if (_unloadModelOverride != null) {
        await _unloadModelOverride!();
      } else {
        await _inferenceMethodChannel.invokeMethod('unloadModel');
      }
    } catch (e) {
      debugPrint('[LocalLLM] Unload warning: $e');
    }

    final previousId = _loadedModelId;
    _loadedModelId = null;
    _loadError = null;
    _updateLoadState(ModelLoadState.unloaded);
    debugPrint('[LocalLLM] Model $previousId unloaded');
  }

  /// Query total GPU memory in MB via TVM OpenCL.
  /// Returns -1 if unavailable (e.g. no OpenCL support).
  Future<int> getGpuMemoryMB() async {
    try {
      final result =
          await _inferenceMethodChannel.invokeMethod<int>('getGpuMemoryMB');
      return result ?? -1;
    } catch (e) {
      debugPrint('[LocalLLM] GPU memory query failed: $e');
      return -1;
    }
  }

  /// Run inference on the loaded model.
  ///
  /// [messagesJson] is a JSON string of OpenAI-format messages.
  /// [toolsJson] is an optional JSON string of OpenAI-format tool schemas.
  /// [maxTokens] limits the response length.
  ///
  /// Returns the Claude-compatible response JSON string.
  Future<String> generate(
    String messagesJson, {
    String? toolsJson,
    int maxTokens = 2048,
  }) async {
    if (_loadedModelId == null || _loadState != ModelLoadState.loaded) {
      throw StateError('No model loaded. Call loadModel() first.');
    }

    _updateLoadState(ModelLoadState.generating);

    try {
      final String result;
      if (_generateOverride != null) {
        result = await _generateOverride!(messagesJson, toolsJson, maxTokens);
      } else {
        final response = await _inferenceMethodChannel.invokeMethod<String>(
          'generate',
          {
            'messagesJson': messagesJson,
            'toolsJson': toolsJson,
            'maxTokens': maxTokens,
          },
        );
        if (response == null) {
          throw Exception('Null response from inference engine');
        }
        result = response;
      }

      _updateLoadState(ModelLoadState.loaded);
      return result;
    } on PlatformException catch (e) {
      if (e.code == 'NO_MODEL') {
        // Native side evicted model (memory pressure) — reset Dart state
        _loadedModelId = null;
        _updateLoadState(ModelLoadState.unloaded);
        debugPrint('[LocalLLM] Model evicted by OS memory pressure');
      } else {
        _updateLoadState(ModelLoadState.loaded); // Stay loaded, just generation failed
      }
      debugPrint('[LocalLLM] Generate failed: ${e.message}');
      rethrow;
    } catch (e) {
      _updateLoadState(ModelLoadState.loaded);
      debugPrint('[LocalLLM] Generate failed: $e');
      rethrow;
    }
  }

  void _updateLoadState(ModelLoadState state) {
    _loadState = state;
    _loadStateController.add(state);
  }

  // -- Download channel helpers --

  Future<void> _startDownload(
      String modelId, String repoId, String destDir) async {
    if (_startDownloadOverride != null) {
      return _startDownloadOverride!(modelId, repoId, destDir);
    }
    await _downloadMethodChannel.invokeMethod('startDownload', {
      'modelId': modelId,
      'repoId': repoId,
      'destDir': destDir,
    });
  }

  Future<void> _cancelDownload(String modelId) async {
    if (_cancelDownloadOverride != null) {
      return _cancelDownloadOverride!(modelId);
    }
    await _downloadMethodChannel.invokeMethod('cancelDownload', {
      'modelId': modelId,
    });
  }

  Future<int> _getAvailableSpace() async {
    if (_getAvailableSpaceOverride != null) {
      return _getAvailableSpaceOverride!();
    }
    final result =
        await _downloadMethodChannel.invokeMethod<int>('getAvailableSpace');
    return result ?? 0;
  }

  void _ensureDownloadEventListener() {
    if (_downloadEventSubscription != null) return;

    final Stream stream;
    if (_downloadEventStreamOverride != null) {
      stream = _downloadEventStreamOverride!;
    } else {
      stream = _downloadEventChannel.receiveBroadcastStream();
    }

    _downloadEventSubscription = stream.listen(
      (event) => _handleDownloadEvent(event as String),
      onError: (error) {
        // EventChannel errors are non-fatal
      },
    );
  }

  void _handleDownloadEvent(String eventJson) {
    try {
      final data = jsonDecode(eventJson) as Map<String, dynamic>;
      final modelId = data['modelId'] as String?;
      final event = data['event'] as String?;
      if (modelId == null || event == null) return;

      // Ignore events for unknown models
      if (!_states.containsKey(modelId)) return;

      switch (event) {
        case 'progress':
          final progress = (data['progress'] as num?)?.toDouble() ?? 0.0;
          _states[modelId] = _states[modelId]!.copyWith(
            downloadState: ModelDownloadState.downloading,
            downloadProgress: progress.clamp(0.0, 1.0),
          );
          // Don't persist progress — too frequent, performance concern
          _emitState();
          break;

        case 'complete':
          _onDownloadComplete(modelId);
          break;

        case 'error':
          final errorMsg = data['errorMessage'] as String? ?? 'Download failed';
          _states[modelId] = OfflineModelState(
            modelId: modelId,
            downloadState: ModelDownloadState.error,
            errorMessage: errorMsg,
          );
          _persistState();
          _emitState();
          break;

        case 'cancelled':
          _states[modelId] = OfflineModelState(modelId: modelId);
          _persistState();
          _emitState();
          break;
      }
    } catch (_) {
      // Malformed JSON — ignore
    }
  }

  Future<void> _onDownloadComplete(String modelId) async {
    final diskUsage = await getModelDiskUsage(modelId);
    _states[modelId] = OfflineModelState(
      modelId: modelId,
      downloadState: ModelDownloadState.downloaded,
      downloadProgress: 1.0,
      diskUsageBytes: diskUsage,
    );
    await _persistState();
    _emitState();
  }

  // -- Internal helpers --

  Future<String?> _getPersistedStates() async {
    if (_getPersistedStatesOverride != null) {
      return _getPersistedStatesOverride!();
    }
    return StorageService.instance.getOfflineModelStates();
  }

  Future<void> _setPersistedStates(String json) async {
    if (_setPersistedStatesOverride != null) {
      return _setPersistedStatesOverride!(json);
    }
    return StorageService.instance.setOfflineModelStates(json);
  }

  Future<void> _restorePersistedState() async {
    final json = await _getPersistedStates();
    if (json == null) return;
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      for (final entry in map.entries) {
        final modelId = entry.key;
        final data = entry.value as Map<String, dynamic>;
        if (_states.containsKey(modelId)) {
          _states[modelId] = OfflineModelState(
            modelId: modelId,
            downloadState: ModelDownloadState.values.firstWhere(
              (s) => s.name == data['downloadState'],
              orElse: () => ModelDownloadState.notDownloaded,
            ),
            diskUsageBytes: data['diskUsageBytes'] as int?,
          );
        }
      }
    } catch (_) {
      // Corrupted persisted state — start fresh
    }
  }

  Future<void> _scanDownloadedModels() async {
    for (final model in ModelRegistry.offlineModels) {
      final currentState = _states[model.id];

      // If persisted state is 'downloading', reset to notDownloaded.
      // App restarted mid-download — Kotlin executor no longer exists.
      if (currentState?.downloadState == ModelDownloadState.downloading) {
        _states[model.id] = OfflineModelState(modelId: model.id);
        continue;
      }

      final downloaded = await isModelDownloaded(model.id);
      if (downloaded) {
        final diskUsage = await getModelDiskUsage(model.id);
        _states[model.id] = OfflineModelState(
          modelId: model.id,
          downloadState: ModelDownloadState.downloaded,
          downloadProgress: 1.0,
          diskUsageBytes: diskUsage,
        );
      } else {
        // If we thought it was downloaded but it's not on disk, reset
        if (_states[model.id]?.downloadState == ModelDownloadState.downloaded) {
          _states[model.id] = OfflineModelState(modelId: model.id);
        }
      }
    }
    await _persistState();
  }

  Future<void> _persistState() async {
    final map = <String, dynamic>{};
    for (final entry in _states.entries) {
      map[entry.key] = {
        'downloadState': entry.value.downloadState.name,
        'diskUsageBytes': entry.value.diskUsageBytes,
      };
    }
    await _setPersistedStates(jsonEncode(map));
  }

  void _emitState() {
    _stateController.add(Map.unmodifiable(_states));
  }

  /// Release resources.
  void dispose() {
    _downloadEventSubscription?.cancel();
    _downloadEventSubscription = null;
    _stateController.close();
    _loadStateController.close();
  }
}
