import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ApiUsage cost calculation', () {
    test('calculates claude-sonnet-4 cost correctly', () {
      final cost = _calculateCost('claude-sonnet-4-20250514', 1000, 500);

      // Input: 1000 tokens at $0.003/1K = $0.003
      // Output: 500 tokens at $0.015/1K = $0.0075
      // Total: $0.0105
      expect(cost, closeTo(0.0105, 0.0001));
    });

    test('calculates claude-haiku-4 cost correctly', () {
      final cost = _calculateCost('claude-haiku-4-20250514', 1000, 500);

      // Input: 1000 tokens at $0.00025/1K = $0.00025
      // Output: 500 tokens at $0.00125/1K = $0.000625
      // Total: $0.000875
      expect(cost, closeTo(0.000875, 0.0001));
    });

    test('uses sonnet pricing for unknown models', () {
      final unknownCost = _calculateCost('unknown-model', 1000, 500);
      final sonnetCost = _calculateCost('claude-sonnet-4-20250514', 1000, 500);

      expect(unknownCost, equals(sonnetCost));
    });

    test('handles zero tokens', () {
      final cost = _calculateCost('claude-sonnet-4-20250514', 0, 0);
      expect(cost, equals(0.0));
    });

    test('handles large token counts', () {
      // 100K input, 50K output (simulating a large conversation)
      final cost = _calculateCost('claude-sonnet-4-20250514', 100000, 50000);

      // Input: 100K at $0.003/1K = $0.30
      // Output: 50K at $0.015/1K = $0.75
      // Total: $1.05
      expect(cost, closeTo(1.05, 0.01));
    });

    test('haiku is significantly cheaper than sonnet', () {
      final sonnetCost = _calculateCost('claude-sonnet-4-20250514', 10000, 5000);
      final haikuCost = _calculateCost('claude-haiku-4-20250514', 10000, 5000);

      // Haiku should be ~12x cheaper
      expect(haikuCost, lessThan(sonnetCost / 10));
    });
  });

  group('Date handling', () {
    test('normalizes date to day granularity', () {
      final now = DateTime(2024, 6, 15, 14, 30, 45, 123, 456);
      final normalized = DateTime(now.year, now.month, now.day);

      expect(normalized.hour, equals(0));
      expect(normalized.minute, equals(0));
      expect(normalized.second, equals(0));
      expect(normalized.millisecond, equals(0));
    });

    test('start of day calculation', () {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      expect(startOfDay.hour, equals(0));
      expect(startOfDay.minute, equals(0));
      expect(startOfDay.second, equals(0));
    });

    test('end of day calculation', () {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      expect(endOfDay.day, equals(today.day + 1));
    });

    test('start of month calculation', () {
      final now = DateTime(2024, 6, 15);
      final startOfMonth = DateTime(now.year, now.month, 1);

      expect(startOfMonth.day, equals(1));
    });

    test('end of month calculation', () {
      final now = DateTime(2024, 6, 15);
      final endOfMonth = DateTime(now.year, now.month + 1, 1);

      expect(endOfMonth.month, equals(7));
      expect(endOfMonth.day, equals(1));
    });

    test('handles year boundary for December', () {
      final december = DateTime(2024, 12, 15);
      final endOfMonth = DateTime(december.year, december.month + 1, 1);

      // Dart DateTime handles month=13 by rolling over
      expect(endOfMonth.year, equals(2025));
      expect(endOfMonth.month, equals(1));
      expect(endOfMonth.day, equals(1));
    });
  });

  group('Cost aggregation', () {
    test('sums costs correctly', () {
      final costs = [0.01, 0.02, 0.015, 0.005];
      final total = costs.fold(0.0, (sum, cost) => sum + cost);

      expect(total, closeTo(0.05, 0.001));
    });

    test('handles empty cost list', () {
      final costs = <double>[];
      final total = costs.fold(0.0, (sum, cost) => sum + cost);

      expect(total, equals(0.0));
    });

    test('sums token counts correctly', () {
      final usages = [
        _MockApiUsage(inputTokens: 1000, outputTokens: 500),
        _MockApiUsage(inputTokens: 2000, outputTokens: 1000),
        _MockApiUsage(inputTokens: 500, outputTokens: 250),
      ];

      int inputTotal = 0;
      int outputTotal = 0;
      for (final usage in usages) {
        inputTotal += usage.inputTokens;
        outputTotal += usage.outputTokens;
      }

      expect(inputTotal, equals(3500));
      expect(outputTotal, equals(1750));
    });
  });

  group('Daily breakdown', () {
    test('groups costs by day', () {
      final usages = [
        _MockApiUsageWithDate(
          date: DateTime(2024, 6, 1),
          cost: 0.10,
        ),
        _MockApiUsageWithDate(
          date: DateTime(2024, 6, 1),
          cost: 0.05,
        ),
        _MockApiUsageWithDate(
          date: DateTime(2024, 6, 2),
          cost: 0.08,
        ),
      ];

      final breakdown = <DateTime, double>{};
      for (final usage in usages) {
        final day = DateTime(usage.date.year, usage.date.month, usage.date.day);
        breakdown[day] = (breakdown[day] ?? 0) + usage.cost;
      }

      expect(breakdown[DateTime(2024, 6, 1)], closeTo(0.15, 0.001));
      expect(breakdown[DateTime(2024, 6, 2)], closeTo(0.08, 0.001));
    });

    test('calculates last N days range', () {
      final now = DateTime(2024, 6, 15);
      final days = 7;
      final start = DateTime(now.year, now.month, now.day - days);

      expect(start.day, equals(8));
      expect(start.month, equals(6));
    });
  });

  group('Cost limits', () {
    test('daily limit checking', () {
      const dailyLimit = 5.0; // $5 per day
      final todayCost = 4.50;

      expect(todayCost < dailyLimit, isTrue);
      expect(todayCost / dailyLimit, closeTo(0.9, 0.01)); // 90% used
    });

    test('detects when daily limit exceeded', () {
      const dailyLimit = 5.0;
      final todayCost = 5.50;

      expect(todayCost > dailyLimit, isTrue);
    });

    test('monthly limit checking', () {
      const monthlyLimit = 50.0; // $50 per month
      final monthCost = 35.0;

      expect(monthCost < monthlyLimit, isTrue);
      expect(monthCost / monthlyLimit, closeTo(0.7, 0.01)); // 70% used
    });

    test('calculates remaining budget', () {
      const dailyLimit = 5.0;
      final todayCost = 3.25;
      final remaining = dailyLimit - todayCost;

      expect(remaining, closeTo(1.75, 0.01));
    });
  });

  group('Usage statistics', () {
    test('calculates average cost per query', () {
      final totalCost = 2.50;
      final queryCount = 100;
      final avgCost = totalCost / queryCount;

      expect(avgCost, closeTo(0.025, 0.001));
    });

    test('calculates average tokens per query', () {
      final totalTokens = 50000;
      final queryCount = 100;
      final avgTokens = totalTokens ~/ queryCount;

      expect(avgTokens, equals(500));
    });

    test('handles division by zero', () {
      final totalCost = 2.50;
      final queryCount = 0;
      final avgCost = queryCount > 0 ? totalCost / queryCount : 0.0;

      expect(avgCost, equals(0.0));
    });
  });

  group('Model comparison', () {
    test('sonnet has higher quality but higher cost', () {
      // Same token usage
      final inputTokens = 10000;
      final outputTokens = 5000;

      final sonnetCost = _calculateCost('claude-sonnet-4-20250514', inputTokens, outputTokens);
      final haikuCost = _calculateCost('claude-haiku-4-20250514', inputTokens, outputTokens);

      expect(sonnetCost, greaterThan(haikuCost));
    });

    test('output tokens cost more than input tokens', () {
      // For sonnet: input=$0.003/1K, output=$0.015/1K (5x more expensive)
      final inputOnlyCost = _calculateCost('claude-sonnet-4-20250514', 1000, 0);
      final outputOnlyCost = _calculateCost('claude-sonnet-4-20250514', 0, 1000);

      expect(outputOnlyCost, greaterThan(inputOnlyCost));
      expect(outputOnlyCost / inputOnlyCost, closeTo(5.0, 0.01));
    });
  });

  group('Edge cases', () {
    test('handles very small token counts', () {
      final cost = _calculateCost('claude-sonnet-4-20250514', 1, 1);
      expect(cost, greaterThan(0));
    });

    test('handles maximum realistic token counts', () {
      // ~200K context window
      final cost = _calculateCost('claude-sonnet-4-20250514', 200000, 4096);

      // Should be a reasonable number
      expect(cost, lessThan(1.0));
      expect(cost, greaterThan(0.5));
    });

    test('precision is maintained for small costs', () {
      final cost = _calculateCost('claude-haiku-4-20250514', 100, 50);

      // Should have meaningful precision
      expect(cost, greaterThan(0));
      expect(cost, lessThan(0.0001));
    });
  });

  group('Cost formatting', () {
    test('formats small costs correctly', () {
      final cost = 0.0125;
      final formatted = _formatCost(cost);

      expect(formatted, equals('\$0.01'));
    });

    test('formats larger costs correctly', () {
      final cost = 1.2567;
      final formatted = _formatCost(cost);

      expect(formatted, equals('\$1.26'));
    });

    test('formats zero cost', () {
      final cost = 0.0;
      final formatted = _formatCost(cost);

      expect(formatted, equals('\$0.00'));
    });

    test('formats very small costs', () {
      final cost = 0.001;
      final formatted = _formatCost(cost);

      expect(formatted, equals('\$0.00'));
    });
  });

  group('Token formatting', () {
    test('formats small token counts', () {
      expect(_formatTokens(100), equals('100'));
      expect(_formatTokens(999), equals('999'));
    });

    test('formats thousands', () {
      expect(_formatTokens(1000), equals('1.0K'));
      expect(_formatTokens(1500), equals('1.5K'));
      expect(_formatTokens(10000), equals('10.0K'));
    });

    test('formats large numbers', () {
      expect(_formatTokens(100000), equals('100.0K'));
      expect(_formatTokens(1000000), equals('1.0M'));
    });
  });

  group('CSV Export', () {
    test('exports empty data correctly', () {
      final csv = _exportToCsv([]);

      expect(csv, contains('Date,Model,Input Tokens,Output Tokens,Cost (USD)'));
      // Only header, no data rows
      final lines = csv.trim().split('\n');
      expect(lines.length, equals(1));
    });

    test('exports single record correctly', () {
      final usages = [
        _MockApiUsageFull(
          date: DateTime(2024, 6, 15),
          model: 'claude-sonnet-4-20250514',
          inputTokens: 1000,
          outputTokens: 500,
          estimatedCostUsd: 0.0105,
        ),
      ];

      final csv = _exportToCsv(usages);
      final lines = csv.trim().split('\n');

      expect(lines.length, equals(2)); // Header + 1 data row
      expect(lines[1], contains('2024-06-15'));
      expect(lines[1], contains('claude-sonnet-4-20250514'));
      expect(lines[1], contains('1000'));
      expect(lines[1], contains('500'));
      expect(lines[1], contains('0.010500'));
    });

    test('exports multiple records correctly', () {
      final usages = [
        _MockApiUsageFull(
          date: DateTime(2024, 6, 15),
          model: 'claude-sonnet-4-20250514',
          inputTokens: 1000,
          outputTokens: 500,
          estimatedCostUsd: 0.0105,
        ),
        _MockApiUsageFull(
          date: DateTime(2024, 6, 16),
          model: 'claude-haiku-4-20250514',
          inputTokens: 2000,
          outputTokens: 1000,
          estimatedCostUsd: 0.00175,
        ),
      ];

      final csv = _exportToCsv(usages);
      final lines = csv.trim().split('\n');

      expect(lines.length, equals(3)); // Header + 2 data rows
    });

    test('formats date with zero-padded month and day', () {
      final usages = [
        _MockApiUsageFull(
          date: DateTime(2024, 1, 5),
          model: 'claude-sonnet-4-20250514',
          inputTokens: 100,
          outputTokens: 50,
          estimatedCostUsd: 0.001,
        ),
      ];

      final csv = _exportToCsv(usages);

      expect(csv, contains('2024-01-05'));
    });

    test('preserves cost precision to 6 decimal places', () {
      final usages = [
        _MockApiUsageFull(
          date: DateTime(2024, 6, 15),
          model: 'claude-haiku-4-20250514',
          inputTokens: 10,
          outputTokens: 5,
          estimatedCostUsd: 0.0000087,
        ),
      ];

      final csv = _exportToCsv(usages);

      // Should have 6 decimal precision
      expect(csv, contains('0.000009')); // Rounded to 6 decimals
    });

    test('handles large token counts', () {
      final usages = [
        _MockApiUsageFull(
          date: DateTime(2024, 6, 15),
          model: 'claude-sonnet-4-20250514',
          inputTokens: 100000,
          outputTokens: 50000,
          estimatedCostUsd: 1.05,
        ),
      ];

      final csv = _exportToCsv(usages);

      expect(csv, contains('100000'));
      expect(csv, contains('50000'));
    });

    test('exports records in sorted order by date', () {
      // Assuming the export maintains insertion order (sorted by date in DB)
      final usages = [
        _MockApiUsageFull(
          date: DateTime(2024, 6, 14),
          model: 'claude-sonnet-4-20250514',
          inputTokens: 100,
          outputTokens: 50,
          estimatedCostUsd: 0.001,
        ),
        _MockApiUsageFull(
          date: DateTime(2024, 6, 15),
          model: 'claude-sonnet-4-20250514',
          inputTokens: 200,
          outputTokens: 100,
          estimatedCostUsd: 0.002,
        ),
        _MockApiUsageFull(
          date: DateTime(2024, 6, 16),
          model: 'claude-sonnet-4-20250514',
          inputTokens: 300,
          outputTokens: 150,
          estimatedCostUsd: 0.003,
        ),
      ];

      final csv = _exportToCsv(usages);
      final lines = csv.trim().split('\n');

      expect(lines[1], contains('2024-06-14'));
      expect(lines[2], contains('2024-06-15'));
      expect(lines[3], contains('2024-06-16'));
    });

    test('handles mixed model types', () {
      final usages = [
        _MockApiUsageFull(
          date: DateTime(2024, 6, 15),
          model: 'claude-sonnet-4-20250514',
          inputTokens: 1000,
          outputTokens: 500,
          estimatedCostUsd: 0.0105,
        ),
        _MockApiUsageFull(
          date: DateTime(2024, 6, 15),
          model: 'claude-haiku-4-20250514',
          inputTokens: 1000,
          outputTokens: 500,
          estimatedCostUsd: 0.000875,
        ),
      ];

      final csv = _exportToCsv(usages);

      expect(csv, contains('claude-sonnet-4-20250514'));
      expect(csv, contains('claude-haiku-4-20250514'));
    });

    test('CSV header matches expected columns', () {
      final csv = _exportToCsv([]);
      final headerLine = csv.trim().split('\n').first;
      final columns = headerLine.split(',');

      expect(columns.length, equals(5));
      expect(columns[0], equals('Date'));
      expect(columns[1], equals('Model'));
      expect(columns[2], equals('Input Tokens'));
      expect(columns[3], equals('Output Tokens'));
      expect(columns[4], equals('Cost (USD)'));
    });

    test('handles zero token counts', () {
      final usages = [
        _MockApiUsageFull(
          date: DateTime(2024, 6, 15),
          model: 'claude-sonnet-4-20250514',
          inputTokens: 0,
          outputTokens: 0,
          estimatedCostUsd: 0.0,
        ),
      ];

      final csv = _exportToCsv(usages);
      final lines = csv.trim().split('\n');

      expect(lines[1], contains(',0,'));
      expect(lines[1], contains('0.000000'));
    });

    test('handles year boundary dates', () {
      final usages = [
        _MockApiUsageFull(
          date: DateTime(2023, 12, 31),
          model: 'claude-sonnet-4-20250514',
          inputTokens: 100,
          outputTokens: 50,
          estimatedCostUsd: 0.001,
        ),
        _MockApiUsageFull(
          date: DateTime(2024, 1, 1),
          model: 'claude-sonnet-4-20250514',
          inputTokens: 200,
          outputTokens: 100,
          estimatedCostUsd: 0.002,
        ),
      ];

      final csv = _exportToCsv(usages);

      expect(csv, contains('2023-12-31'));
      expect(csv, contains('2024-01-01'));
    });

    test('handles very small costs correctly', () {
      final usages = [
        _MockApiUsageFull(
          date: DateTime(2024, 6, 15),
          model: 'claude-haiku-4-20250514',
          inputTokens: 1,
          outputTokens: 1,
          estimatedCostUsd: 0.00000175,
        ),
      ];

      final csv = _exportToCsv(usages);

      // Should preserve precision
      expect(csv, contains('0.000002')); // Rounded
    });

    test('handles multiple records on same day', () {
      final usages = [
        _MockApiUsageFull(
          date: DateTime(2024, 6, 15),
          model: 'claude-sonnet-4-20250514',
          inputTokens: 1000,
          outputTokens: 500,
          estimatedCostUsd: 0.0105,
        ),
        _MockApiUsageFull(
          date: DateTime(2024, 6, 15),
          model: 'claude-sonnet-4-20250514',
          inputTokens: 2000,
          outputTokens: 1000,
          estimatedCostUsd: 0.021,
        ),
        _MockApiUsageFull(
          date: DateTime(2024, 6, 15),
          model: 'claude-haiku-4-20250514',
          inputTokens: 500,
          outputTokens: 250,
          estimatedCostUsd: 0.0004375,
        ),
      ];

      final csv = _exportToCsv(usages);
      final lines = csv.trim().split('\n');

      // Header + 3 data rows
      expect(lines.length, equals(4));

      // All on same date
      final dateCount = lines.where((l) => l.contains('2024-06-15')).length;
      expect(dateCount, equals(3));
    });
  });

  group('Cost limit thresholds', () {
    test('calculates percentage used correctly', () {
      const limit = 5.0;
      const used = 4.0;
      final percentUsed = (used / limit) * 100;

      expect(percentUsed, equals(80.0));
    });

    test('handles 0% usage', () {
      const limit = 5.0;
      const used = 0.0;
      final percentUsed = limit > 0 ? (used / limit) * 100 : 0.0;

      expect(percentUsed, equals(0.0));
    });

    test('handles 100% usage', () {
      const limit = 5.0;
      const used = 5.0;
      final percentUsed = (used / limit) * 100;

      expect(percentUsed, equals(100.0));
    });

    test('handles over 100% usage', () {
      const limit = 5.0;
      const used = 7.5;
      final percentUsed = (used / limit) * 100;

      expect(percentUsed, equals(150.0));
    });

    test('warning threshold at 80%', () {
      const warningThreshold = 80.0;
      const limit = 5.0;
      const used = 4.0;
      final percentUsed = (used / limit) * 100;

      expect(percentUsed >= warningThreshold, isTrue);
    });

    test('below warning threshold at 79%', () {
      const warningThreshold = 80.0;
      const limit = 5.0;
      const used = 3.95;
      final percentUsed = (used / limit) * 100;

      expect(percentUsed < warningThreshold, isTrue);
    });

    test('hard block at 100%', () {
      const blockThreshold = 100.0;
      const limit = 5.0;
      const used = 5.0;
      final percentUsed = (used / limit) * 100;

      expect(percentUsed >= blockThreshold, isTrue);
    });

    test('handles very small limit', () {
      const limit = 0.01;
      const used = 0.005;
      final percentUsed = (used / limit) * 100;

      expect(percentUsed, equals(50.0));
    });

    test('handles zero limit gracefully', () {
      const limit = 0.0;
      const used = 1.0;
      final percentUsed = limit > 0 ? (used / limit) * 100 : 0.0;

      expect(percentUsed, equals(0.0)); // Avoid division by zero
    });
  });

  group('Cost limit state management', () {
    test('daily limit is checked independently of monthly', () {
      const dailyLimit = 2.0;
      const monthlyLimit = 50.0;
      const dailyUsed = 2.5; // Over daily
      const monthlyUsed = 10.0; // Under monthly

      final dailyExceeded = dailyUsed >= dailyLimit;
      final monthlyExceeded = monthlyUsed >= monthlyLimit;

      expect(dailyExceeded, isTrue);
      expect(monthlyExceeded, isFalse);
    });

    test('monthly limit exceeded blocks even if daily is fine', () {
      const dailyLimit = 5.0;
      const monthlyLimit = 10.0;
      const dailyUsed = 2.0; // Under daily
      const monthlyUsed = 12.0; // Over monthly

      final dailyExceeded = dailyUsed >= dailyLimit;
      final monthlyExceeded = monthlyUsed >= monthlyLimit;
      final isBlocked = dailyExceeded || monthlyExceeded;

      expect(isBlocked, isTrue);
    });

    test('neither limit exceeded allows operation', () {
      const dailyLimit = 5.0;
      const monthlyLimit = 50.0;
      const dailyUsed = 2.0;
      const monthlyUsed = 20.0;

      final dailyExceeded = dailyUsed >= dailyLimit;
      final monthlyExceeded = monthlyUsed >= monthlyLimit;
      final isBlocked = dailyExceeded || monthlyExceeded;

      expect(isBlocked, isFalse);
    });

    test('disabled limits allow any usage', () {
      const limitEnabled = false;
      const dailyUsed = 100.0;
      const dailyLimit = 5.0;

      final isBlocked = limitEnabled && (dailyUsed >= dailyLimit);

      expect(isBlocked, isFalse);
    });

    test('enabled limits enforce usage', () {
      const limitEnabled = true;
      const dailyUsed = 100.0;
      const dailyLimit = 5.0;

      final isBlocked = limitEnabled && (dailyUsed >= dailyLimit);

      expect(isBlocked, isTrue);
    });
  });

  group('Usage accumulation edge cases', () {
    test('handles midnight boundary for daily reset', () {
      final yesterday = DateTime(2024, 6, 14, 23, 59, 59);
      final today = DateTime(2024, 6, 15, 0, 0, 1);

      final yesterdayNormalized = DateTime(yesterday.year, yesterday.month, yesterday.day);
      final todayNormalized = DateTime(today.year, today.month, today.day);

      expect(yesterdayNormalized, isNot(equals(todayNormalized)));
    });

    test('handles month boundary for monthly reset', () {
      final lastDayOfMonth = DateTime(2024, 6, 30);
      final firstDayOfNextMonth = DateTime(2024, 7, 1);

      final monthJune = DateTime(lastDayOfMonth.year, lastDayOfMonth.month, 1);
      final monthJuly = DateTime(firstDayOfNextMonth.year, firstDayOfNextMonth.month, 1);

      expect(monthJune.month, equals(6));
      expect(monthJuly.month, equals(7));
    });

    test('handles leap year February correctly', () {
      final feb28 = DateTime(2024, 2, 28);
      final feb29 = DateTime(2024, 2, 29);
      final mar1 = DateTime(2024, 3, 1);

      expect(feb29.day, equals(29)); // 2024 is leap year
      expect(mar1.month, equals(3));
    });

    test('accumulates costs from multiple small queries', () {
      final costs = List.generate(100, (_) => 0.001); // 100 tiny queries
      final total = costs.fold(0.0, (sum, cost) => sum + cost);

      expect(total, closeTo(0.1, 0.001));
    });
  });
}

// Helper functions that simulate the implementation

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

String _formatCost(double cost) {
  return '\$${cost.toStringAsFixed(2)}';
}

String _formatTokens(int tokens) {
  if (tokens >= 1000000) {
    return '${(tokens / 1000000).toStringAsFixed(1)}M';
  }
  if (tokens >= 1000) {
    return '${(tokens / 1000).toStringAsFixed(1)}K';
  }
  return tokens.toString();
}

// Mock classes
class _MockApiUsage {
  final int inputTokens;
  final int outputTokens;

  _MockApiUsage({
    required this.inputTokens,
    required this.outputTokens,
  });
}

class _MockApiUsageWithDate {
  final DateTime date;
  final double cost;

  _MockApiUsageWithDate({
    required this.date,
    required this.cost,
  });
}

class _MockApiUsageFull {
  final DateTime date;
  final String model;
  final int inputTokens;
  final int outputTokens;
  final double estimatedCostUsd;

  _MockApiUsageFull({
    required this.date,
    required this.model,
    required this.inputTokens,
    required this.outputTokens,
    required this.estimatedCostUsd,
  });
}

/// Simulates the exportToCsv logic from ApiUsageRepository
String _exportToCsv(List<_MockApiUsageFull> usages) {
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
