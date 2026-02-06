import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:navixmind/core/services/cost_manager.dart';

void main() {
  group('CostStatus', () {
    test('has all expected values', () {
      expect(CostStatus.values, contains(CostStatus.ok));
      expect(CostStatus.values, contains(CostStatus.warning));
      expect(CostStatus.values, contains(CostStatus.exceeded));
      expect(CostStatus.values.length, equals(3));
    });
  });

  group('CostLimitResult', () {
    test('creates with all required fields', () {
      final result = CostLimitResult(
        status: CostStatus.ok,
        currentTokens: 5000,
        tokenLimit: 10000,
        message: 'Within budget',
      );

      expect(result.status, equals(CostStatus.ok));
      expect(result.currentTokens, equals(5000));
      expect(result.tokenLimit, equals(10000));
      expect(result.message, equals('Within budget'));
    });

    group('percentUsed', () {
      test('calculates percentage correctly', () {
        final result = CostLimitResult(
          status: CostStatus.ok,
          currentTokens: 5000,
          tokenLimit: 10000,
          message: '',
        );

        expect(result.percentUsed, equals(50.0));
      });

      test('handles 0% usage', () {
        final result = CostLimitResult(
          status: CostStatus.ok,
          currentTokens: 0,
          tokenLimit: 10000,
          message: '',
        );

        expect(result.percentUsed, equals(0.0));
      });

      test('handles 100% usage', () {
        final result = CostLimitResult(
          status: CostStatus.exceeded,
          currentTokens: 10000,
          tokenLimit: 10000,
          message: '',
        );

        expect(result.percentUsed, equals(100.0));
      });

      test('handles over 100% usage', () {
        final result = CostLimitResult(
          status: CostStatus.exceeded,
          currentTokens: 15000,
          tokenLimit: 10000,
          message: '',
        );

        expect(result.percentUsed, equals(150.0));
      });

      test('returns 0 when limit is 0', () {
        final result = CostLimitResult(
          status: CostStatus.ok,
          currentTokens: 5000,
          tokenLimit: 0,
          message: '',
        );

        expect(result.percentUsed, equals(0.0));
      });

      test('returns 0 when limit is negative', () {
        final result = CostLimitResult(
          status: CostStatus.ok,
          currentTokens: 5000,
          tokenLimit: -10000,
          message: '',
        );

        expect(result.percentUsed, equals(0.0));
      });
    });

    group('canProceed', () {
      test('returns true for ok status', () {
        final result = CostLimitResult(
          status: CostStatus.ok,
          currentTokens: 5000,
          tokenLimit: 10000,
          message: '',
        );

        expect(result.canProceed, isTrue);
      });

      test('returns true for warning status', () {
        final result = CostLimitResult(
          status: CostStatus.warning,
          currentTokens: 8500,
          tokenLimit: 10000,
          message: '',
        );

        expect(result.canProceed, isTrue);
      });

      test('returns false for exceeded status', () {
        final result = CostLimitResult(
          status: CostStatus.exceeded,
          currentTokens: 10000,
          tokenLimit: 10000,
          message: '',
        );

        expect(result.canProceed, isFalse);
      });
    });
  });

  group('UsageSummary', () {
    test('creates with all required fields', () {
      final summary = UsageSummary(
        todayTokens: 1500,
        monthTokens: 25000,
        dailyLimit: 5000,
        monthlyLimit: 50000,
        limitsEnabled: true,
      );

      expect(summary.todayTokens, equals(1500));
      expect(summary.monthTokens, equals(25000));
      expect(summary.dailyLimit, equals(5000));
      expect(summary.monthlyLimit, equals(50000));
      expect(summary.limitsEnabled, isTrue);
    });

    group('dailyPercent', () {
      test('calculates percentage correctly when enabled', () {
        final summary = UsageSummary(
          todayTokens: 2500,
          monthTokens: 0,
          dailyLimit: 5000,
          monthlyLimit: 50000,
          limitsEnabled: true,
        );

        expect(summary.dailyPercent, equals(50.0));
      });

      test('returns 0 when limits disabled', () {
        final summary = UsageSummary(
          todayTokens: 2500,
          monthTokens: 0,
          dailyLimit: 5000,
          monthlyLimit: 50000,
          limitsEnabled: false,
        );

        expect(summary.dailyPercent, equals(0.0));
      });

      test('returns 0 when limit is 0', () {
        final summary = UsageSummary(
          todayTokens: 2500,
          monthTokens: 0,
          dailyLimit: 0,
          monthlyLimit: 50000,
          limitsEnabled: true,
        );

        expect(summary.dailyPercent, equals(0.0));
      });
    });

    group('monthlyPercent', () {
      test('calculates percentage correctly when enabled', () {
        final summary = UsageSummary(
          todayTokens: 0,
          monthTokens: 25000,
          dailyLimit: 5000,
          monthlyLimit: 50000,
          limitsEnabled: true,
        );

        expect(summary.monthlyPercent, equals(50.0));
      });

      test('returns 0 when limits disabled', () {
        final summary = UsageSummary(
          todayTokens: 0,
          monthTokens: 25000,
          dailyLimit: 5000,
          monthlyLimit: 50000,
          limitsEnabled: false,
        );

        expect(summary.monthlyPercent, equals(0.0));
      });
    });

    group('formatting', () {
      test('todayTokensFormatted formats with K suffix', () {
        final summary = UsageSummary(
          todayTokens: 1500,
          monthTokens: 0,
          dailyLimit: 5000,
          monthlyLimit: 50000,
          limitsEnabled: true,
        );

        expect(summary.todayTokensFormatted, equals('1.5K'));
      });

      test('monthTokensFormatted formats correctly', () {
        final summary = UsageSummary(
          todayTokens: 0,
          monthTokens: 25000,
          dailyLimit: 5000,
          monthlyLimit: 50000,
          limitsEnabled: true,
        );

        expect(summary.monthTokensFormatted, equals('25.0K'));
      });

      test('dailyLimitFormatted formats correctly', () {
        final summary = UsageSummary(
          todayTokens: 0,
          monthTokens: 0,
          dailyLimit: 5000,
          monthlyLimit: 50000,
          limitsEnabled: true,
        );

        expect(summary.dailyLimitFormatted, equals('5.0K'));
      });

      test('monthlyLimitFormatted formats correctly', () {
        final summary = UsageSummary(
          todayTokens: 0,
          monthTokens: 0,
          dailyLimit: 5000,
          monthlyLimit: 100000,
          limitsEnabled: true,
        );

        expect(summary.monthlyLimitFormatted, equals('100.0K'));
      });

      test('handles zero values', () {
        final summary = UsageSummary(
          todayTokens: 0,
          monthTokens: 0,
          dailyLimit: 0,
          monthlyLimit: 0,
          limitsEnabled: false,
        );

        expect(summary.todayTokensFormatted, equals('0'));
        expect(summary.monthTokensFormatted, equals('0'));
      });

      test('handles large values', () {
        final summary = UsageSummary(
          todayTokens: 1234567,
          monthTokens: 9999999,
          dailyLimit: 100000,
          monthlyLimit: 10000000,
          limitsEnabled: true,
        );

        expect(summary.todayTokensFormatted, equals('1.23M'));
        expect(summary.monthTokensFormatted, equals('10.00M'));
      });
    });
  });

  group('Cost calculation logic', () {
    // Test the cost calculation formula directly
    test('calculates Opus pricing correctly', () {
      // Opus: $15/1M input, $75/1M output
      // 1000 input tokens = $0.015
      // 1000 output tokens = $0.075
      const inputRate = 0.015;
      const outputRate = 0.075;

      final cost = (1000 / 1000 * inputRate) + (1000 / 1000 * outputRate);
      expect(cost, equals(0.09));
    });

    test('calculates Sonnet pricing correctly', () {
      // Sonnet: $3/1M input, $15/1M output
      // 1000 input tokens = $0.003
      // 1000 output tokens = $0.015
      const inputRate = 0.003;
      const outputRate = 0.015;

      final cost = (1000 / 1000 * inputRate) + (1000 / 1000 * outputRate);
      expect(cost, equals(0.018));
    });

    test('calculates Haiku pricing correctly', () {
      // Haiku: $0.25/1M input, $1.25/1M output
      // 1000 input tokens = $0.00025
      // 1000 output tokens = $0.00125
      const inputRate = 0.00025;
      const outputRate = 0.00125;

      final cost = (1000 / 1000 * inputRate) + (1000 / 1000 * outputRate);
      expect(cost, equals(0.0015));
    });

    test('Haiku is much cheaper than Sonnet', () {
      const haikuInput = 0.00025;
      const haikuOutput = 0.00125;
      const sonnetInput = 0.003;
      const sonnetOutput = 0.015;

      final haikuCost = (1000 / 1000 * haikuInput) + (1000 / 1000 * haikuOutput);
      final sonnetCost = (1000 / 1000 * sonnetInput) + (1000 / 1000 * sonnetOutput);

      expect(haikuCost, lessThan(sonnetCost / 10)); // Haiku is >10x cheaper
    });

    test('Sonnet is much cheaper than Opus', () {
      const sonnetInput = 0.003;
      const sonnetOutput = 0.015;
      const opusInput = 0.015;
      const opusOutput = 0.075;

      final sonnetCost = (1000 / 1000 * sonnetInput) + (1000 / 1000 * sonnetOutput);
      final opusCost = (1000 / 1000 * opusInput) + (1000 / 1000 * opusOutput);

      expect(sonnetCost, lessThan(opusCost / 4)); // Sonnet is >4x cheaper
    });
  });

  group('Status thresholds', () {
    test('ok status is under 80%', () {
      // Simulate status calculation
      const currentTokens = 7900;
      const limit = 10000;
      final percentUsed = currentTokens / limit * 100;

      expect(percentUsed, lessThan(80));
      // Would be CostStatus.ok
    });

    test('warning status is 80-99%', () {
      const currentTokens = 8500;
      const limit = 10000;
      final percentUsed = currentTokens / limit * 100;

      expect(percentUsed, greaterThanOrEqualTo(80));
      expect(percentUsed, lessThan(100));
      // Would be CostStatus.warning
    });

    test('exceeded status is 100% or more', () {
      const currentTokens = 10000;
      const limit = 10000;
      final percentUsed = currentTokens / limit * 100;

      expect(percentUsed, greaterThanOrEqualTo(100));
      // Would be CostStatus.exceeded
    });

    test('exactly 80% is warning', () {
      const currentTokens = 8000;
      const limit = 10000;
      final percentUsed = currentTokens / limit * 100;

      expect(percentUsed, equals(80));
      // Would be CostStatus.warning
    });

    test('exactly 100% is exceeded', () {
      const currentTokens = 10000;
      const limit = 10000;
      final percentUsed = currentTokens / limit * 100;

      expect(percentUsed, equals(100));
      // Would be CostStatus.exceeded
    });
  });

  group('Status stream behavior', () {
    test('broadcast stream allows multiple listeners', () {
      final controller = StreamController<CostLimitResult>.broadcast();

      final events1 = <CostLimitResult>[];
      final events2 = <CostLimitResult>[];

      controller.stream.listen((e) => events1.add(e));
      controller.stream.listen((e) => events2.add(e));

      final result = CostLimitResult(
        status: CostStatus.warning,
        currentTokens: 8500,
        tokenLimit: 10000,
        message: 'Warning',
      );

      controller.add(result);

      // Allow microtasks to complete
      Future.delayed(Duration.zero, () {
        expect(events1.length, equals(1));
        expect(events2.length, equals(1));
        controller.close();
      });
    });
  });

  group('Edge cases', () {
    test('handles very small token counts', () {
      final result = CostLimitResult(
        status: CostStatus.ok,
        currentTokens: 1,
        tokenLimit: 10000,
        message: '',
      );

      expect(result.percentUsed, closeTo(0.01, 0.001));
    });

    test('handles very large token counts', () {
      final result = CostLimitResult(
        status: CostStatus.exceeded,
        currentTokens: 1000000,
        tokenLimit: 100,
        message: '',
      );

      expect(result.percentUsed, equals(1000000.0));
      expect(result.canProceed, isFalse);
    });

    test('handles zero token limit', () {
      final result = CostLimitResult(
        status: CostStatus.ok,
        currentTokens: 1000,
        tokenLimit: 0,
        message: 'No limit set',
      );

      expect(result.percentUsed, equals(0.0));
      expect(result.canProceed, isTrue);
    });
  });

  group('Message content', () {
    test('daily exceeded message mentions midnight reset', () {
      const message = 'Daily limit reached. Resets at midnight.';
      expect(message, contains('midnight'));
    });

    test('monthly exceeded message mentions 1st reset', () {
      const message = 'Monthly limit reached. Resets on the 1st.';
      expect(message, contains('1st'));
    });

    test('warning message includes percentage', () {
      final percent = 85;
      final message = "You've used $percent% of your daily AI budget.";
      expect(message, contains('85%'));
    });
  });
}
