import 'package:isar/isar.dart';

part 'api_usage.g.dart';

@collection
class ApiUsage {
  Id id = Isar.autoIncrement;

  /// Date at day granularity
  @Index()
  late DateTime date;

  late String model;

  late int inputTokens;

  late int outputTokens;

  late double estimatedCostUsd;

  ApiUsage();

  factory ApiUsage.create({
    required String model,
    required int inputTokens,
    required int outputTokens,
  }) {
    final now = DateTime.now();
    return ApiUsage()
      ..date = DateTime(now.year, now.month, now.day)
      ..model = model
      ..inputTokens = inputTokens
      ..outputTokens = outputTokens
      ..estimatedCostUsd = _calculateCost(model, inputTokens, outputTokens);
  }

  /// Calculate cost based on model pricing
  static double _calculateCost(String model, int inputTokens, int outputTokens) {
    // Pricing per 1K tokens (as of spec date)
    const pricing = {
      'claude-sonnet-4-20250514': {'input': 0.003, 'output': 0.015},
      'claude-haiku-4-20250514': {'input': 0.00025, 'output': 0.00125},
    };

    final modelPricing = pricing[model] ?? pricing['claude-sonnet-4-20250514']!;
    final inputCost = (inputTokens / 1000) * modelPricing['input']!;
    final outputCost = (outputTokens / 1000) * modelPricing['output']!;

    return inputCost + outputCost;
  }
}

/// Repository for API usage tracking
class ApiUsageRepository {
  final Isar _isar;

  ApiUsageRepository(this._isar);

  /// Record a new API call
  Future<void> recordUsage({
    required String model,
    required int inputTokens,
    required int outputTokens,
  }) async {
    await _isar.writeTxn(() async {
      await _isar.apiUsages.put(ApiUsage.create(
        model: model,
        inputTokens: inputTokens,
        outputTokens: outputTokens,
      ));
    });
  }

  /// Get total cost for today
  Future<double> getTodayCost() async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final usages = await _isar.apiUsages
        .where()
        .dateBetween(startOfDay, endOfDay)
        .findAll();

    return usages.fold<double>(0.0, (double sum, usage) => sum + usage.estimatedCostUsd);
  }

  /// Get total cost for this month
  Future<double> getMonthCost() async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 1);

    final usages = await _isar.apiUsages
        .where()
        .dateBetween(startOfMonth, endOfMonth)
        .findAll();

    return usages.fold<double>(0.0, (double sum, usage) => sum + usage.estimatedCostUsd);
  }

  /// Get total cost for a date range
  Future<double> getCostForRange(DateTime start, DateTime end) async {
    final usages = await _isar.apiUsages
        .where()
        .dateBetween(start, end)
        .findAll();

    return usages.fold<double>(0.0, (double sum, usage) => sum + usage.estimatedCostUsd);
  }

  /// Get daily breakdown for the last N days
  Future<Map<DateTime, double>> getDailyBreakdown(int days) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day - days);

    final usages = await _isar.apiUsages
        .where()
        .dateGreaterThan(start)
        .findAll();

    final breakdown = <DateTime, double>{};
    for (final usage in usages) {
      final day = DateTime(usage.date.year, usage.date.month, usage.date.day);
      breakdown[day] = (breakdown[day] ?? 0) + usage.estimatedCostUsd;
    }

    return breakdown;
  }

  /// Get total token counts for today
  Future<Map<String, int>> getTodayTokens() async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final usages = await _isar.apiUsages
        .where()
        .dateBetween(startOfDay, endOfDay)
        .findAll();

    int input = 0;
    int output = 0;
    for (final usage in usages) {
      input += usage.inputTokens;
      output += usage.outputTokens;
    }

    return {'input': input, 'output': output, 'total': input + output};
  }

  /// Get total token counts for this month
  Future<Map<String, int>> getMonthTokens() async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 1);

    final usages = await _isar.apiUsages
        .where()
        .dateBetween(startOfMonth, endOfMonth)
        .findAll();

    int input = 0;
    int output = 0;
    for (final usage in usages) {
      input += usage.inputTokens;
      output += usage.outputTokens;
    }

    return {'input': input, 'output': output, 'total': input + output};
  }

  /// Get all usage data for export
  Future<List<ApiUsage>> getAllUsage() async {
    return _isar.apiUsages.where().sortByDate().findAll();
  }

  /// Export all usage data to CSV format
  Future<String> exportToCsv() async {
    final usages = await getAllUsage();

    final buffer = StringBuffer();
    // Header
    buffer.writeln('Date,Model,Input Tokens,Output Tokens,Cost (USD)');

    // Data rows
    for (final usage in usages) {
      final dateStr =
          '${usage.date.year}-${usage.date.month.toString().padLeft(2, '0')}-${usage.date.day.toString().padLeft(2, '0')}';
      buffer.writeln(
          '$dateStr,${usage.model},${usage.inputTokens},${usage.outputTokens},${usage.estimatedCostUsd.toStringAsFixed(6)}');
    }

    return buffer.toString();
  }
}
