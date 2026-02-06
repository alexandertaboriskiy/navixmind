import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Service to monitor network connectivity
class ConnectivityService {
  static final ConnectivityService instance = ConnectivityService._();

  ConnectivityService._();

  final _connectivity = Connectivity();
  final _statusController = StreamController<bool>.broadcast();

  StreamSubscription<ConnectivityResult>? _subscription;
  Timer? _recheckTimer;
  bool _isOnline = true;

  /// Stream of online/offline status
  Stream<bool> get statusStream => _statusController.stream;

  /// Current online status
  bool get isOnline => _isOnline;

  /// Alias for isOnline for more semantic API
  bool get isConnected => _isOnline;

  /// Initialize connectivity monitoring
  Future<void> initialize() async {
    // Check initial status
    final result = await _connectivity.checkConnectivity();
    _updateStatus(result);

    // Listen for changes
    _subscription = _connectivity.onConnectivityChanged.listen(_updateStatus);

    // Periodic recheck to recover from stale offline state
    _recheckTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (!_isOnline) {
        final fresh = await _connectivity.checkConnectivity();
        _updateStatus(fresh);
      }
    });
  }

  void _updateStatus(ConnectivityResult result) {
    final wasOnline = _isOnline;
    _isOnline = result != ConnectivityResult.none;

    if (wasOnline != _isOnline) {
      _statusController.add(_isOnline);
    }
  }

  /// Check if currently online (fresh check, also updates cached state)
  Future<bool> checkConnectivity() async {
    final result = await _connectivity.checkConnectivity();
    _updateStatus(result);
    return _isOnline;
  }

  void dispose() {
    _recheckTimer?.cancel();
    _subscription?.cancel();
    _statusController.close();
  }
}
