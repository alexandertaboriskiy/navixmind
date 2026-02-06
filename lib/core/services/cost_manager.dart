import 'dart:async';

import 'package:isar/isar.dart';

import '../database/collections/api_usage.dart';
import 'storage_service.dart';

/// Cost status for the current period
enum CostStatus {
  /// Under 80% of limit - normal operation
  ok,

  /// 80-99% of limit - show warning
  warning,

  /// At or over 100% of limit - block queries
  exceeded,
}

/// Result of a cost limit check
class CostLimitResult {
  final CostStatus status;
  final int currentTokens;
  final int tokenLimit;
  final String message;

  CostLimitResult({
    required this.status,
    required this.currentTokens,
    required this.tokenLimit,
    required this.message,
  });

  double get percentUsed => tokenLimit > 0 ? (currentTokens / tokenLimit * 100) : 0;

  bool get canProceed => status != CostStatus.exceeded;
}

/// Manager for API token tracking and limit enforcement.
///
/// Tracks daily and monthly API usage tokens from the ApiUsage Isar collection
/// and enforces configurable spending limits.
class CostManager {
  static final CostManager instance = CostManager._();

  CostManager._();

  Isar? _isar;
  final _storageService = StorageService.instance;
  final _statusController = StreamController<CostLimitResult>.broadcast();

  /// Stream of cost status changes for UI updates
  Stream<CostLimitResult> get statusStream => _statusController.stream;

  /// Initialize with Isar database reference
  void initialize(Isar isar) {
    _isar = isar;
  }

  /// Check if the user can make a new API call based on token limits.
  ///
  /// Returns a [CostLimitResult] indicating:
  /// - ok: Under 80% of limit, proceed normally
  /// - warning: 80-99% of limit, show warning but allow
  /// - exceeded: At or over limit, block the query
  Future<CostLimitResult> checkDailyLimit() async {
    final enabled = await _storageService.isCostLimitEnabled();
    if (!enabled) {
      return CostLimitResult(
        status: CostStatus.ok,
        currentTokens: await getTodayTokens(),
        tokenLimit: 0,
        message: 'Token limits disabled',
      );
    }

    final limit = await _storageService.getDailyTokenLimit();
    final currentTokens = await getTodayTokens();

    return _calculateStatus(currentTokens, limit, 'daily');
  }

  /// Check monthly token limit
  Future<CostLimitResult> checkMonthlyLimit() async {
    final enabled = await _storageService.isCostLimitEnabled();
    if (!enabled) {
      return CostLimitResult(
        status: CostStatus.ok,
        currentTokens: await getMonthTokens(),
        tokenLimit: 0,
        message: 'Token limits disabled',
      );
    }

    final limit = await _storageService.getMonthlyTokenLimit();
    final currentTokens = await getMonthTokens();

    return _calculateStatus(currentTokens, limit, 'monthly');
  }

  /// Check both daily and monthly limits, return the most restrictive
  Future<CostLimitResult> checkAllLimits() async {
    final daily = await checkDailyLimit();
    final monthly = await checkMonthlyLimit();

    // Return the more restrictive result
    if (daily.status == CostStatus.exceeded) return daily;
    if (monthly.status == CostStatus.exceeded) return monthly;
    if (daily.status == CostStatus.warning) return daily;
    if (monthly.status == CostStatus.warning) return monthly;
    return daily;
  }

  CostLimitResult _calculateStatus(
    int currentTokens,
    int limit,
    String period,
  ) {
    if (limit <= 0) {
      // No limit set (unlimited)
      return CostLimitResult(
        status: CostStatus.ok,
        currentTokens: currentTokens,
        tokenLimit: 0,
        message: 'No $period limit set',
      );
    }

    final percentUsed = currentTokens / limit * 100;

    if (percentUsed >= 100) {
      final result = CostLimitResult(
        status: CostStatus.exceeded,
        currentTokens: currentTokens,
        tokenLimit: limit,
        message: _getExceededMessage(period),
      );
      _statusController.add(result);
      return result;
    }

    if (percentUsed >= 80) {
      final result = CostLimitResult(
        status: CostStatus.warning,
        currentTokens: currentTokens,
        tokenLimit: limit,
        message: _getWarningMessage(percentUsed.round(), period),
      );
      _statusController.add(result);
      return result;
    }

    return CostLimitResult(
      status: CostStatus.ok,
      currentTokens: currentTokens,
      tokenLimit: limit,
      message: 'Within $period budget',
    );
  }

  String _getExceededMessage(String period) {
    if (period == 'daily') {
      return 'Daily token limit reached. Resets at midnight.';
    }
    return 'Monthly token limit reached. Resets on the 1st.';
  }

  String _getWarningMessage(int percent, String period) {
    return "You've used $percent% of your $period token budget.";
  }

  /// Get total tokens for today
  Future<int> getTodayTokens() async {
    if (_isar == null) return 0;

    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final usages = await _isar!.apiUsages
        .filter()
        .dateGreaterThan(startOfDay)
        .dateLessThan(endOfDay)
        .findAll();

    return usages.fold<int>(0, (int sum, usage) => sum + usage.inputTokens + usage.outputTokens);
  }

  /// Get total tokens for current month
  Future<int> getMonthTokens() async {
    if (_isar == null) return 0;

    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 1);

    final usages = await _isar!.apiUsages
        .filter()
        .dateGreaterThan(startOfMonth)
        .dateLessThan(endOfMonth)
        .findAll();

    return usages.fold<int>(0, (int sum, usage) => sum + usage.inputTokens + usage.outputTokens);
  }

  /// Record API usage
  Future<void> recordUsage({
    required String model,
    required int inputTokens,
    required int outputTokens,
  }) async {
    if (_isar == null) return;

    final cost = _calculateCost(model, inputTokens, outputTokens);

    final usage = ApiUsage()
      ..date = DateTime.now()
      ..model = model
      ..inputTokens = inputTokens
      ..outputTokens = outputTokens
      ..estimatedCostUsd = cost;

    await _isar!.writeTxn(() async {
      await _isar!.apiUsages.put(usage);
    });

    // Check if we've crossed any thresholds after recording
    await checkAllLimits();
  }

  /// Calculate cost based on model and tokens
  double _calculateCost(String model, int inputTokens, int outputTokens) {
    // Pricing per 1K tokens (as of spec date)
    double inputRate;
    double outputRate;

    if (model.contains('opus')) {
      inputRate = 0.015; // $15 per 1M tokens
      outputRate = 0.075; // $75 per 1M tokens
    } else if (model.contains('sonnet')) {
      inputRate = 0.003; // $3 per 1M tokens
      outputRate = 0.015; // $15 per 1M tokens
    } else if (model.contains('haiku')) {
      inputRate = 0.00025; // $0.25 per 1M tokens
      outputRate = 0.00125; // $1.25 per 1M tokens
    } else {
      // Default to Sonnet pricing
      inputRate = 0.003;
      outputRate = 0.015;
    }

    return (inputTokens / 1000 * inputRate) + (outputTokens / 1000 * outputRate);
  }

  /// Get the user's preferred model setting
  Future<String> getPreferredModel() async {
    return await _storageService.getPreferredModel();
  }

  /// Get usage summary for display
  Future<UsageSummary> getUsageSummary() async {
    final todayTokens = await getTodayTokens();
    final monthTokens = await getMonthTokens();
    final dailyLimit = await _storageService.getDailyTokenLimit();
    final monthlyLimit = await _storageService.getMonthlyTokenLimit();
    final enabled = await _storageService.isCostLimitEnabled();

    return UsageSummary(
      todayTokens: todayTokens,
      monthTokens: monthTokens,
      dailyLimit: dailyLimit,
      monthlyLimit: monthlyLimit,
      limitsEnabled: enabled,
    );
  }

  void dispose() {
    _statusController.close();
  }
}

/// Summary of API usage and limits
class UsageSummary {
  final int todayTokens;
  final int monthTokens;
  final int dailyLimit;
  final int monthlyLimit;
  final bool limitsEnabled;

  UsageSummary({
    required this.todayTokens,
    required this.monthTokens,
    required this.dailyLimit,
    required this.monthlyLimit,
    required this.limitsEnabled,
  });

  double get dailyPercent =>
      limitsEnabled && dailyLimit > 0 ? (todayTokens / dailyLimit * 100) : 0;

  double get monthlyPercent =>
      limitsEnabled && monthlyLimit > 0 ? (monthTokens / monthlyLimit * 100) : 0;

  String _formatTokens(int tokens) {
    if (tokens >= 1000000) {
      return '${(tokens / 1000000).toStringAsFixed(2)}M';
    } else if (tokens >= 1000) {
      return '${(tokens / 1000).toStringAsFixed(1)}K';
    }
    return '$tokens';
  }

  String get todayTokensFormatted => _formatTokens(todayTokens);
  String get monthTokensFormatted => _formatTokens(monthTokens);
  String get dailyLimitFormatted => _formatTokens(dailyLimit);
  String get monthlyLimitFormatted => _formatTokens(monthlyLimit);
}
