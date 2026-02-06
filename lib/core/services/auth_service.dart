import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'analytics_service.dart';

/// Service for managing Google OAuth authentication
class AuthService {
  static final AuthService instance = AuthService._();

  AuthService._();

  // Only request the minimum scopes needed:
  // - gmail.readonly: read emails
  // - calendar.events: view/edit calendar events
  // disconnect() before signIn() forces a fresh consent prompt.
  final _googleSignIn = GoogleSignIn(
    serverClientId:
        '296863031657-69hn38bhprhqvrda6vd795sp65e8764d.apps.googleusercontent.com',
    scopes: [
      'email',
      'https://www.googleapis.com/auth/gmail.readonly',
      'https://www.googleapis.com/auth/calendar.events',
    ],
  );

  GoogleSignInAccount? _currentUser;
  final _userController = StreamController<GoogleSignInAccount?>.broadcast();

  /// Stream of current signed-in user
  Stream<GoogleSignInAccount?> get userStream => _userController.stream;

  /// Current signed-in user
  GoogleSignInAccount? get currentUser => _currentUser;

  /// Whether user is signed in
  bool get isSignedIn => _currentUser != null;

  /// Initialize auth service - check for existing sign-in
  Future<void> initialize() async {
    _googleSignIn.onCurrentUserChanged.listen((account) {
      _currentUser = account;
      _userController.add(account);
    });

    // Try silent sign-in (no UI if already authorized)
    try {
      _currentUser = await _googleSignIn.signInSilently();
      debugPrint('Google silent sign-in: ${_currentUser != null ? "restored" : "no session"}');
    } catch (e) {
      debugPrint('Google silent sign-in failed: $e');
    }
  }

  /// Sign in with Google.
  ///
  /// After sign-in, requests any scopes not yet granted so the user is
  /// prompted for Calendar/Gmail access even if they previously signed in
  /// with fewer scopes.
  Future<GoogleSignInAccount?> signIn() async {
    await AnalyticsService.instance.googleSignInStarted();
    try {
      _currentUser = await _googleSignIn.signIn();

      // If sign-in succeeded, ensure all declared scopes are granted.
      // google_sign_in caches old grants; requestScopes() prompts only
      // for scopes not yet authorized — without revoking the session.
      if (_currentUser != null) {
        final granted = await _googleSignIn.requestScopes([
          'https://www.googleapis.com/auth/gmail.readonly',
          'https://www.googleapis.com/auth/calendar.events',
        ]);
        if (!granted) {
          debugPrint('User declined additional scopes');
        }
      }

      await AnalyticsService.instance.googleSignInCompleted(success: _currentUser != null);
      return _currentUser;
    } catch (e) {
      await AnalyticsService.instance.googleSignInCompleted(success: false);
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
    _userController.add(null);
    await AnalyticsService.instance.googleSignOut();
  }

  /// Disconnect (revoke access).
  /// Always clears local state even if the server-side disconnect fails.
  Future<void> disconnect() async {
    try {
      await _googleSignIn.disconnect();
    } catch (e) {
      debugPrint('Google disconnect error (ignored): $e');
    }
    _currentUser = null;
    _userController.add(null);
  }

  /// Get a valid access token, refreshing if needed.
  /// The token carries whatever scopes the user granted.
  Future<String?> getValidAccessToken() async {
    if (_currentUser == null) return null;

    try {
      final auth = await _currentUser!.authentication;
      return auth.accessToken;
    } catch (e) {
      // Try silent refresh (no UI)
      try {
        _currentUser = await _googleSignIn.signInSilently();
        if (_currentUser == null) return null;
        final auth = await _currentUser!.authentication;
        return auth.accessToken;
      } catch (e) {
        debugPrint('Token refresh failed: $e');
        return null;
      }
    }
  }

  /// Get token expiry time (approximate)
  /// Google tokens typically last 1 hour
  DateTime get tokenExpiry {
    // Google access tokens last ~3600 seconds
    // We estimate based on last auth time
    return DateTime.now().add(const Duration(minutes: 55));
  }

  void dispose() {
    _userController.close();
  }
}
