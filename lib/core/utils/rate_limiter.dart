/// Rate limiting constants
const int maxRequestsPerMinute = 20;
const int maxToolCallsPerQuery = 50;
const int maxAgentLoops = 50;

/// Client-side rate limiter to prevent abuse and runaway loops
class RateLimiter {
  final List<DateTime> _timestamps = [];
  int _toolCallsThisQuery = 0;
  int _agentLoopsThisQuery = 0;

  /// Check if a new request can proceed
  bool canProceed() {
    _cleanup();
    return _timestamps.length < maxRequestsPerMinute;
  }

  /// Record a new request
  void recordRequest() {
    _timestamps.add(DateTime.now());
  }

  /// Reset per-query counters
  void resetQueryCounters() {
    _toolCallsThisQuery = 0;
    _agentLoopsThisQuery = 0;
  }

  /// Check and increment tool call counter
  bool canMakeToolCall() {
    if (_toolCallsThisQuery >= maxToolCallsPerQuery) {
      return false;
    }
    _toolCallsThisQuery++;
    return true;
  }

  /// Check and increment agent loop counter
  bool canContinueAgentLoop() {
    if (_agentLoopsThisQuery >= maxAgentLoops) {
      return false;
    }
    _agentLoopsThisQuery++;
    return true;
  }

  /// Get current request count
  int get currentRequestCount {
    _cleanup();
    return _timestamps.length;
  }

  /// Get remaining requests this minute
  int get remainingRequests {
    _cleanup();
    return maxRequestsPerMinute - _timestamps.length;
  }

  /// Get time until next request is allowed (if rate limited)
  Duration? get timeUntilNextRequest {
    _cleanup();
    if (_timestamps.length < maxRequestsPerMinute) {
      return null;
    }
    // Time until oldest request expires
    final oldest = _timestamps.first;
    final expiresAt = oldest.add(const Duration(minutes: 1));
    return expiresAt.difference(DateTime.now());
  }

  void _cleanup() {
    final cutoff = DateTime.now().subtract(const Duration(minutes: 1));
    _timestamps.removeWhere((t) => t.isBefore(cutoff));
  }
}

/// Global rate limiter instance
final rateLimiter = RateLimiter();
