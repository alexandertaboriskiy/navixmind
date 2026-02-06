import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

/// Secure storage service for sensitive data
class StorageService {
  static final StorageService instance = StorageService._();

  StorageService._();

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // Keys
  static const _keyApiKey = 'claude_api_key';
  static const _keyGoogleRefreshToken = 'google_refresh_token';
  static const _keyDailyLimit = 'daily_cost_limit';
  static const _keyMonthlyLimit = 'monthly_cost_limit';
  static const _keyLimitEnabled = 'cost_limit_enabled';
  static const _keyPreferredModel = 'preferred_model';
  static const _keyDailyTokenLimit = 'daily_token_limit';
  static const _keyMonthlyTokenLimit = 'monthly_token_limit';
  static const _keyToolTimeout = 'tool_timeout_seconds';
  static const _keyMaxIterations = 'max_agent_iterations';
  static const _keyMaxToolCalls = 'max_tool_calls';
  static const _keyMaxTokens = 'max_response_tokens';
  static const _keyLegalAccepted = 'legal_accepted';
  static const _keySelfImproveEnabled = 'self_improve_enabled';

  /// Store Claude API key securely
  Future<void> setApiKey(String key) async {
    await _storage.write(key: _keyApiKey, value: key);
  }

  /// Get stored API key
  Future<String?> getApiKey() async {
    return await _storage.read(key: _keyApiKey);
  }

  /// Check if API key is stored
  Future<bool> hasApiKey() async {
    return await _storage.containsKey(key: _keyApiKey);
  }

  /// Delete API key
  Future<void> deleteApiKey() async {
    await _storage.delete(key: _keyApiKey);
  }

  /// Store Google refresh token (if needed for manual refresh)
  Future<void> setGoogleRefreshToken(String token) async {
    await _storage.write(key: _keyGoogleRefreshToken, value: token);
  }

  /// Get Google refresh token
  Future<String?> getGoogleRefreshToken() async {
    return await _storage.read(key: _keyGoogleRefreshToken);
  }

  /// Delete Google refresh token
  Future<void> deleteGoogleRefreshToken() async {
    await _storage.delete(key: _keyGoogleRefreshToken);
  }

  /// Clear all secure storage
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  // Cost limit methods

  /// Set daily cost limit
  Future<void> setDailyLimit(double limit) async {
    await _storage.write(key: _keyDailyLimit, value: limit.toString());
  }

  /// Get daily cost limit (default: 0.50)
  Future<double> getDailyLimit() async {
    final value = await _storage.read(key: _keyDailyLimit);
    return value != null ? double.tryParse(value) ?? 0.50 : 0.50;
  }

  /// Set monthly cost limit
  Future<void> setMonthlyLimit(double limit) async {
    await _storage.write(key: _keyMonthlyLimit, value: limit.toString());
  }

  /// Get monthly cost limit (default: 10.00)
  Future<double> getMonthlyLimit() async {
    final value = await _storage.read(key: _keyMonthlyLimit);
    return value != null ? double.tryParse(value) ?? 10.00 : 10.00;
  }

  /// Enable/disable cost limits
  Future<void> setCostLimitEnabled(bool enabled) async {
    await _storage.write(key: _keyLimitEnabled, value: enabled.toString());
  }

  /// Check if cost limits are enabled (default: true)
  Future<bool> isCostLimitEnabled() async {
    final value = await _storage.read(key: _keyLimitEnabled);
    return value != 'false';
  }

  // Model preference methods

  /// Set preferred model ('auto', 'sonnet', 'haiku')
  Future<void> setPreferredModel(String model) async {
    await _storage.write(key: _keyPreferredModel, value: model);
  }

  /// Get preferred model (default: 'auto')
  Future<String> getPreferredModel() async {
    final value = await _storage.read(key: _keyPreferredModel);
    return value ?? 'auto';
  }

  // Token limit methods

  /// Set daily token limit (input + output combined)
  Future<void> setDailyTokenLimit(int tokens) async {
    await _storage.write(key: _keyDailyTokenLimit, value: tokens.toString());
  }

  /// Get daily token limit (default: 100,000 tokens)
  Future<int> getDailyTokenLimit() async {
    final value = await _storage.read(key: _keyDailyTokenLimit);
    return value != null ? int.tryParse(value) ?? 100000 : 100000;
  }

  /// Set monthly token limit
  Future<void> setMonthlyTokenLimit(int tokens) async {
    await _storage.write(key: _keyMonthlyTokenLimit, value: tokens.toString());
  }

  /// Get monthly token limit (default: 1,000,000 tokens)
  Future<int> getMonthlyTokenLimit() async {
    final value = await _storage.read(key: _keyMonthlyTokenLimit);
    return value != null ? int.tryParse(value) ?? 1000000 : 1000000;
  }

  // Tool timeout methods

  /// Set tool timeout in seconds
  Future<void> setToolTimeout(int seconds) async {
    await _storage.write(key: _keyToolTimeout, value: seconds.toString());
  }

  /// Get tool timeout in seconds (default: 30)
  Future<int> getToolTimeout() async {
    final value = await _storage.read(key: _keyToolTimeout);
    return value != null ? int.tryParse(value) ?? 30 : 30;
  }

  // Agent loop limits

  /// Set max agent iterations per query
  Future<void> setMaxIterations(int iterations) async {
    await _storage.write(key: _keyMaxIterations, value: iterations.toString());
  }

  /// Get max agent iterations (default: 50)
  Future<int> getMaxIterations() async {
    final value = await _storage.read(key: _keyMaxIterations);
    return value != null ? int.tryParse(value) ?? 50 : 50;
  }

  /// Set max tool calls per query
  Future<void> setMaxToolCalls(int calls) async {
    await _storage.write(key: _keyMaxToolCalls, value: calls.toString());
  }

  /// Get max tool calls per query (default: 50)
  Future<int> getMaxToolCalls() async {
    final value = await _storage.read(key: _keyMaxToolCalls);
    return value != null ? int.tryParse(value) ?? 50 : 50;
  }

  /// Set max response tokens per API call
  Future<void> setMaxTokens(int tokens) async {
    await _storage.write(key: _keyMaxTokens, value: tokens.toString());
  }

  /// Get max response tokens per API call (default: 16384)
  Future<int> getMaxTokens() async {
    final value = await _storage.read(key: _keyMaxTokens);
    return value != null ? int.tryParse(value) ?? 16384 : 16384;
  }

  // Legal acceptance methods

  /// Set legal terms accepted
  Future<void> setLegalAccepted(bool accepted) async {
    await _storage.write(key: _keyLegalAccepted, value: accepted.toString());
  }

  /// Check if legal terms have been accepted
  Future<bool> isLegalAccepted() async {
    final value = await _storage.read(key: _keyLegalAccepted);
    return value == 'true';
  }

  // Self-improve methods

  /// Enable/disable self-improve button below assistant messages
  Future<void> setSelfImproveEnabled(bool enabled) async {
    await _storage.write(key: _keySelfImproveEnabled, value: enabled.toString());
  }

  /// Check if self-improve is enabled (default: false)
  Future<bool> isSelfImproveEnabled() async {
    final value = await _storage.read(key: _keySelfImproveEnabled);
    return value == 'true';
  }

  // System prompt methods (file-based — prompts can be large)

  /// Get the system prompt file path.
  Future<File> getSystemPromptFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/system_prompt.txt');
  }

  /// Read the custom system prompt, or null if not customized.
  Future<String?> getSystemPrompt() async {
    final file = await getSystemPromptFile();
    if (await file.exists()) {
      final content = await file.readAsString();
      return content.isNotEmpty ? content : null;
    }
    return null;
  }

  /// Save a custom system prompt.
  Future<void> setSystemPrompt(String prompt) async {
    final file = await getSystemPromptFile();
    await file.writeAsString(prompt);
  }

  /// Delete the custom system prompt (reverts to default).
  Future<void> resetSystemPrompt() async {
    final file = await getSystemPromptFile();
    if (await file.exists()) {
      await file.delete();
    }
  }
}
