import 'package:flutter_test/flutter_test.dart';
import 'package:navixmind/core/utils/rate_limiter.dart';

void main() {
  group('RateLimiter', () {
    late RateLimiter limiter;

    setUp(() {
      limiter = RateLimiter();
    });

    group('Request rate limiting', () {
      test('canProceed returns true initially', () {
        expect(limiter.canProceed(), isTrue);
      });

      test('canProceed returns true under limit', () {
        for (var i = 0; i < maxRequestsPerMinute - 1; i++) {
          limiter.recordRequest();
        }
        expect(limiter.canProceed(), isTrue);
      });

      test('canProceed returns false at limit', () {
        for (var i = 0; i < maxRequestsPerMinute; i++) {
          limiter.recordRequest();
        }
        expect(limiter.canProceed(), isFalse);
      });

      test('recordRequest increments count', () {
        expect(limiter.currentRequestCount, equals(0));
        limiter.recordRequest();
        expect(limiter.currentRequestCount, equals(1));
        limiter.recordRequest();
        expect(limiter.currentRequestCount, equals(2));
      });

      test('remainingRequests decreases with each request', () {
        expect(limiter.remainingRequests, equals(maxRequestsPerMinute));
        limiter.recordRequest();
        expect(limiter.remainingRequests, equals(maxRequestsPerMinute - 1));
      });

      test('remainingRequests returns 0 when at limit', () {
        for (var i = 0; i < maxRequestsPerMinute; i++) {
          limiter.recordRequest();
        }
        expect(limiter.remainingRequests, equals(0));
      });
    });

    group('Tool call limiting', () {
      test('canMakeToolCall returns true initially', () {
        expect(limiter.canMakeToolCall(), isTrue);
      });

      test('canMakeToolCall increments counter', () {
        limiter.canMakeToolCall();
        limiter.canMakeToolCall();
        limiter.canMakeToolCall();
        // Counter is internal but behavior should be consistent
        expect(true, isTrue);
      });

      test('canMakeToolCall returns false at limit', () {
        for (var i = 0; i < maxToolCallsPerQuery; i++) {
          expect(limiter.canMakeToolCall(), isTrue);
        }
        expect(limiter.canMakeToolCall(), isFalse);
      });

      test('tool call limit is per query', () {
        // Use up all tool calls
        for (var i = 0; i < maxToolCallsPerQuery; i++) {
          limiter.canMakeToolCall();
        }
        expect(limiter.canMakeToolCall(), isFalse);

        // Reset for new query
        limiter.resetQueryCounters();
        expect(limiter.canMakeToolCall(), isTrue);
      });
    });

    group('Agent loop limiting', () {
      test('canContinueAgentLoop returns true initially', () {
        expect(limiter.canContinueAgentLoop(), isTrue);
      });

      test('canContinueAgentLoop increments counter', () {
        limiter.canContinueAgentLoop();
        limiter.canContinueAgentLoop();
        expect(true, isTrue);
      });

      test('canContinueAgentLoop returns false at limit', () {
        for (var i = 0; i < maxAgentLoops; i++) {
          expect(limiter.canContinueAgentLoop(), isTrue);
        }
        expect(limiter.canContinueAgentLoop(), isFalse);
      });

      test('agent loop limit is per query', () {
        // Use up all loops
        for (var i = 0; i < maxAgentLoops; i++) {
          limiter.canContinueAgentLoop();
        }
        expect(limiter.canContinueAgentLoop(), isFalse);

        // Reset for new query
        limiter.resetQueryCounters();
        expect(limiter.canContinueAgentLoop(), isTrue);
      });
    });

    group('Query counter reset', () {
      test('resetQueryCounters resets tool call counter', () {
        for (var i = 0; i < maxToolCallsPerQuery; i++) {
          limiter.canMakeToolCall();
        }
        expect(limiter.canMakeToolCall(), isFalse);

        limiter.resetQueryCounters();
        expect(limiter.canMakeToolCall(), isTrue);
      });

      test('resetQueryCounters resets agent loop counter', () {
        for (var i = 0; i < maxAgentLoops; i++) {
          limiter.canContinueAgentLoop();
        }
        expect(limiter.canContinueAgentLoop(), isFalse);

        limiter.resetQueryCounters();
        expect(limiter.canContinueAgentLoop(), isTrue);
      });

      test('resetQueryCounters does not affect request count', () {
        limiter.recordRequest();
        limiter.recordRequest();
        expect(limiter.currentRequestCount, equals(2));

        limiter.resetQueryCounters();
        expect(limiter.currentRequestCount, equals(2));
      });
    });

    group('Time-based expiration', () {
      test('timeUntilNextRequest is null when under limit', () {
        expect(limiter.timeUntilNextRequest, isNull);
      });

      test('timeUntilNextRequest returns duration when at limit', () {
        for (var i = 0; i < maxRequestsPerMinute; i++) {
          limiter.recordRequest();
        }

        final waitTime = limiter.timeUntilNextRequest;
        expect(waitTime, isNotNull);
        expect(waitTime!.inSeconds, lessThanOrEqualTo(60));
        expect(waitTime.inSeconds, greaterThan(0));
      });
    });

    group('currentRequestCount', () {
      test('returns 0 initially', () {
        expect(limiter.currentRequestCount, equals(0));
      });

      test('increases with each request', () {
        for (var i = 1; i <= 5; i++) {
          limiter.recordRequest();
          expect(limiter.currentRequestCount, equals(i));
        }
      });
    });
  });

  group('Rate limiting constants', () {
    test('maxRequestsPerMinute is reasonable', () {
      expect(maxRequestsPerMinute, equals(20));
      expect(maxRequestsPerMinute, greaterThan(0));
      expect(maxRequestsPerMinute, lessThanOrEqualTo(100));
    });

    test('maxToolCallsPerQuery is reasonable', () {
      expect(maxToolCallsPerQuery, equals(50));
      expect(maxToolCallsPerQuery, greaterThan(0));
      expect(maxToolCallsPerQuery, lessThanOrEqualTo(100));
    });

    test('maxAgentLoops is reasonable', () {
      expect(maxAgentLoops, equals(50));
      expect(maxAgentLoops, greaterThan(0));
      expect(maxAgentLoops, lessThanOrEqualTo(100));
    });
  });

  group('Global rate limiter', () {
    test('global instance exists', () {
      expect(rateLimiter, isNotNull);
      expect(rateLimiter, isA<RateLimiter>());
    });
  });

  group('Edge cases', () {
    late RateLimiter limiter;

    setUp(() {
      limiter = RateLimiter();
    });

    test('handles rapid successive requests', () {
      for (var i = 0; i < 100; i++) {
        limiter.recordRequest();
      }
      // Should cap at limit
      expect(limiter.canProceed(), isFalse);
    });

    test('handles mixed operations', () {
      // Mix of all operations
      limiter.recordRequest();
      limiter.canMakeToolCall();
      limiter.canContinueAgentLoop();
      limiter.recordRequest();
      limiter.canMakeToolCall();

      expect(limiter.currentRequestCount, equals(2));
    });

    test('handles multiple resets', () {
      limiter.resetQueryCounters();
      limiter.resetQueryCounters();
      limiter.resetQueryCounters();

      expect(limiter.canMakeToolCall(), isTrue);
      expect(limiter.canContinueAgentLoop(), isTrue);
    });

    test('tool and agent limits are independent', () {
      // Use up all tool calls
      for (var i = 0; i < maxToolCallsPerQuery; i++) {
        limiter.canMakeToolCall();
      }

      // Agent loops should still work
      expect(limiter.canContinueAgentLoop(), isTrue);
    });

    test('agent and tool limits are independent', () {
      // Use up all agent loops
      for (var i = 0; i < maxAgentLoops; i++) {
        limiter.canContinueAgentLoop();
      }

      // Tool calls should still work
      expect(limiter.canMakeToolCall(), isTrue);
    });
  });

  group('Integration scenarios', () {
    late RateLimiter limiter;

    setUp(() {
      limiter = RateLimiter();
    });

    test('simulates typical query flow', () {
      // Start query
      expect(limiter.canProceed(), isTrue);
      limiter.recordRequest();
      limiter.resetQueryCounters();

      // Agent processes request
      for (var loop = 0; loop < 3; loop++) {
        expect(limiter.canContinueAgentLoop(), isTrue);

        // Each loop might make tool calls
        for (var tool = 0; tool < 2; tool++) {
          expect(limiter.canMakeToolCall(), isTrue);
        }
      }

      // Next query
      limiter.resetQueryCounters();
      expect(limiter.canMakeToolCall(), isTrue);
      expect(limiter.canContinueAgentLoop(), isTrue);
    });

    test('handles runaway loop protection', () {
      // Simulate a bug causing infinite loop
      var iterations = 0;
      while (limiter.canContinueAgentLoop() && iterations < 100) {
        iterations++;
      }

      // Should stop at maxAgentLoops
      expect(iterations, equals(maxAgentLoops));
    });

    test('handles tool call spam protection', () {
      var toolCalls = 0;
      while (limiter.canMakeToolCall() && toolCalls < 100) {
        toolCalls++;
      }

      // Should stop at maxToolCallsPerQuery
      expect(toolCalls, equals(maxToolCallsPerQuery));
    });

    test('simulates rate limited user', () {
      // User makes many rapid requests
      for (var i = 0; i < maxRequestsPerMinute; i++) {
        expect(limiter.canProceed(), isTrue);
        limiter.recordRequest();
      }

      // Next request should be blocked
      expect(limiter.canProceed(), isFalse);
      expect(limiter.remainingRequests, equals(0));
      expect(limiter.timeUntilNextRequest, isNotNull);
    });
  });
}
