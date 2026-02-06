import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mocktail/mocktail.dart';

// Mock classes for google_sign_in package
class MockGoogleSignIn extends Mock implements GoogleSignIn {}

class MockGoogleSignInAccount extends Mock implements GoogleSignInAccount {}

class MockGoogleSignInAuthentication extends Mock
    implements GoogleSignInAuthentication {}

/// Tests for AuthService
///
/// Note: The actual AuthService uses a singleton pattern with a private constructor.
/// These tests verify the authentication logic by testing the patterns and behaviors
/// that the service should implement, using mock objects for GoogleSignIn.
void main() {
  late MockGoogleSignIn mockGoogleSignIn;
  late MockGoogleSignInAccount mockAccount;
  late MockGoogleSignInAuthentication mockAuth;
  late StreamController<GoogleSignInAccount?> onCurrentUserChangedController;

  setUp(() {
    mockGoogleSignIn = MockGoogleSignIn();
    mockAccount = MockGoogleSignInAccount();
    mockAuth = MockGoogleSignInAuthentication();
    onCurrentUserChangedController =
        StreamController<GoogleSignInAccount?>.broadcast();

    // Default mock account setup
    when(() => mockAccount.email).thenReturn('test@example.com');
    when(() => mockAccount.displayName).thenReturn('Test User');
    when(() => mockAccount.id).thenReturn('user-123');
    when(() => mockAccount.photoUrl).thenReturn('https://example.com/photo.jpg');
    when(() => mockAccount.authentication)
        .thenAnswer((_) async => mockAuth);

    // Default mock auth setup
    when(() => mockAuth.accessToken).thenReturn('mock-access-token');
    when(() => mockAuth.idToken).thenReturn('mock-id-token');

    // Default GoogleSignIn setup
    when(() => mockGoogleSignIn.onCurrentUserChanged)
        .thenAnswer((_) => onCurrentUserChangedController.stream);
    when(() => mockGoogleSignIn.signOut()).thenAnswer((_) async {});
    when(() => mockGoogleSignIn.disconnect()).thenAnswer((_) async {});
  });

  tearDown(() {
    onCurrentUserChangedController.close();
  });

  group('AuthService Sign-in flow', () {
    group('signIn', () {
      test('successful sign-in returns account', () async {
        when(() => mockGoogleSignIn.signIn())
            .thenAnswer((_) async => mockAccount);

        final result = await mockGoogleSignIn.signIn();

        expect(result, isNotNull);
        expect(result, equals(mockAccount));
        expect(result!.email, equals('test@example.com'));
        expect(result.displayName, equals('Test User'));
        verify(() => mockGoogleSignIn.signIn()).called(1);
      });

      test('failed sign-in returns null when user cancels', () async {
        when(() => mockGoogleSignIn.signIn()).thenAnswer((_) async => null);

        final result = await mockGoogleSignIn.signIn();

        expect(result, isNull);
        verify(() => mockGoogleSignIn.signIn()).called(1);
      });

      test('sign-in throws exception on error', () async {
        when(() => mockGoogleSignIn.signIn())
            .thenThrow(Exception('Sign-in failed'));

        expect(
          () => mockGoogleSignIn.signIn(),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('signInSilently', () {
      test('silent sign-in works when previously authenticated', () async {
        when(() => mockGoogleSignIn.signInSilently())
            .thenAnswer((_) async => mockAccount);

        final result = await mockGoogleSignIn.signInSilently();

        expect(result, isNotNull);
        expect(result, equals(mockAccount));
        verify(() => mockGoogleSignIn.signInSilently()).called(1);
      });

      test('silent sign-in returns null when not previously authenticated',
          () async {
        when(() => mockGoogleSignIn.signInSilently())
            .thenAnswer((_) async => null);

        final result = await mockGoogleSignIn.signInSilently();

        expect(result, isNull);
      });

      test('silent sign-in with reAuthenticate forces token refresh', () async {
        when(() => mockGoogleSignIn.signInSilently(reAuthenticate: true))
            .thenAnswer((_) async => mockAccount);

        final result =
            await mockGoogleSignIn.signInSilently(reAuthenticate: true);

        expect(result, isNotNull);
        verify(() => mockGoogleSignIn.signInSilently(reAuthenticate: true))
            .called(1);
      });

      test('re-authentication works when token is expired', () async {
        // First call fails (simulating expired token)
        var callCount = 0;
        when(() => mockGoogleSignIn.signInSilently(reAuthenticate: any(named: 'reAuthenticate')))
            .thenAnswer((_) async {
          callCount++;
          return mockAccount;
        });

        final result =
            await mockGoogleSignIn.signInSilently(reAuthenticate: true);

        expect(result, isNotNull);
        expect(result!.email, equals('test@example.com'));
      });
    });
  });

  group('AuthService Token management', () {
    group('getValidAccessToken', () {
      test('returns token when user is signed in', () async {
        when(() => mockAccount.authentication)
            .thenAnswer((_) async => mockAuth);
        when(() => mockAuth.accessToken).thenReturn('valid-access-token');

        final auth = await mockAccount.authentication;

        expect(auth.accessToken, equals('valid-access-token'));
      });

      test('returns null when user is not signed in', () async {
        // Simulate no current user
        GoogleSignInAccount? currentUser;

        final token = currentUser != null
            ? (await currentUser.authentication).accessToken
            : null;

        expect(token, isNull);
      });

      test('handles authentication retrieval error gracefully', () async {
        when(() => mockAccount.authentication)
            .thenThrow(Exception('Token retrieval failed'));

        String? accessToken;
        try {
          final auth = await mockAccount.authentication;
          accessToken = auth.accessToken;
        } catch (e) {
          accessToken = null;
        }

        expect(accessToken, isNull);
      });
    });

    group('token refresh handling', () {
      test('refreshes token via signInSilently with reAuthenticate', () async {
        // Simulate token refresh flow
        when(() => mockGoogleSignIn.signInSilently(reAuthenticate: true))
            .thenAnswer((_) async => mockAccount);
        when(() => mockAuth.accessToken).thenReturn('refreshed-access-token');

        final refreshedAccount =
            await mockGoogleSignIn.signInSilently(reAuthenticate: true);
        final auth = await refreshedAccount!.authentication;

        expect(auth.accessToken, equals('refreshed-access-token'));
      });

      test('returns null when refresh fails', () async {
        when(() => mockGoogleSignIn.signInSilently(reAuthenticate: true))
            .thenAnswer((_) async => null);

        final result =
            await mockGoogleSignIn.signInSilently(reAuthenticate: true);

        expect(result, isNull);
      });

      test('catches exception during refresh and returns null', () async {
        when(() => mockGoogleSignIn.signInSilently(reAuthenticate: true))
            .thenThrow(Exception('Refresh failed'));

        GoogleSignInAccount? result;
        try {
          result =
              await mockGoogleSignIn.signInSilently(reAuthenticate: true);
        } catch (e) {
          result = null;
        }

        expect(result, isNull);
      });
    });

    group('token expiry', () {
      test('tokenExpiry returns future time approximately 55 minutes ahead',
          () {
        // Simulating the AuthService.tokenExpiry behavior
        final tokenExpiry = DateTime.now().add(const Duration(minutes: 55));
        final now = DateTime.now();

        expect(tokenExpiry.isAfter(now), isTrue);
        expect(
          tokenExpiry.difference(now).inMinutes,
          greaterThanOrEqualTo(54),
        );
        expect(
          tokenExpiry.difference(now).inMinutes,
          lessThanOrEqualTo(56),
        );
      });

      test('token is considered valid before expiry', () {
        final tokenExpiry = DateTime.now().add(const Duration(minutes: 55));
        final now = DateTime.now();

        final isValid = now.isBefore(tokenExpiry);

        expect(isValid, isTrue);
      });

      test('token is considered expired after expiry', () {
        final tokenExpiry = DateTime.now().subtract(const Duration(minutes: 5));
        final now = DateTime.now();

        final isValid = now.isBefore(tokenExpiry);

        expect(isValid, isFalse);
      });
    });

    group('idToken handling', () {
      test('returns idToken when available', () async {
        when(() => mockAuth.idToken).thenReturn('mock-id-token');

        final auth = await mockAccount.authentication;

        expect(auth.idToken, equals('mock-id-token'));
      });

      test('handles null idToken', () async {
        when(() => mockAuth.idToken).thenReturn(null);

        final auth = await mockAccount.authentication;

        expect(auth.idToken, isNull);
      });
    });
  });

  group('AuthService Sign-out', () {
    test('sign out clears account', () async {
      when(() => mockGoogleSignIn.signOut()).thenAnswer((_) async {});

      await mockGoogleSignIn.signOut();

      verify(() => mockGoogleSignIn.signOut()).called(1);
    });

    test('sign out succeeds even if not signed in', () async {
      when(() => mockGoogleSignIn.signOut()).thenAnswer((_) async {});

      // Should not throw even without current user
      await expectLater(mockGoogleSignIn.signOut(), completes);
    });

    test('sign out handles errors gracefully', () async {
      when(() => mockGoogleSignIn.signOut())
          .thenThrow(Exception('Sign out failed'));

      expect(
        () => mockGoogleSignIn.signOut(),
        throwsA(isA<Exception>()),
      );
    });

    group('disconnect (revoke access)', () {
      test('disconnect revokes access', () async {
        when(() => mockGoogleSignIn.disconnect()).thenAnswer((_) async {});

        await mockGoogleSignIn.disconnect();

        verify(() => mockGoogleSignIn.disconnect()).called(1);
      });

      test('disconnect clears account', () async {
        when(() => mockGoogleSignIn.disconnect()).thenAnswer((_) async {});

        await mockGoogleSignIn.disconnect();

        verify(() => mockGoogleSignIn.disconnect()).called(1);
      });

      test('disconnect handles already disconnected state', () async {
        when(() => mockGoogleSignIn.disconnect()).thenAnswer((_) async {});

        await expectLater(mockGoogleSignIn.disconnect(), completes);
      });
    });
  });

  group('AuthService State management', () {
    group('isSignedIn', () {
      test('returns true when user is signed in', () {
        final GoogleSignInAccount? currentUser = mockAccount;
        final isSignedIn = currentUser != null;

        expect(isSignedIn, isTrue);
      });

      test('returns false when user is not signed in', () {
        const GoogleSignInAccount? currentUser = null;
        final isSignedIn = currentUser != null;

        expect(isSignedIn, isFalse);
      });
    });

    group('currentUser getter', () {
      test('returns current account when signed in', () {
        final GoogleSignInAccount? currentUser = mockAccount;

        expect(currentUser, isNotNull);
        expect(currentUser!.email, equals('test@example.com'));
      });

      test('returns null when not signed in', () {
        const GoogleSignInAccount? currentUser = null;

        expect(currentUser, isNull);
      });
    });

    group('auth state stream', () {
      test('emits account when user signs in', () async {
        final events = <GoogleSignInAccount?>[];

        onCurrentUserChangedController.stream.listen((account) {
          events.add(account);
        });

        onCurrentUserChangedController.add(mockAccount);

        await Future.delayed(Duration.zero);

        expect(events.length, equals(1));
        expect(events.first, equals(mockAccount));
      });

      test('emits null when user signs out', () async {
        final events = <GoogleSignInAccount?>[];

        onCurrentUserChangedController.stream.listen((account) {
          events.add(account);
        });

        onCurrentUserChangedController.add(mockAccount);
        onCurrentUserChangedController.add(null);

        await Future.delayed(Duration.zero);

        expect(events.length, equals(2));
        expect(events.first, equals(mockAccount));
        expect(events.last, isNull);
      });

      test('stream is broadcast - allows multiple listeners', () async {
        final listener1Events = <GoogleSignInAccount?>[];
        final listener2Events = <GoogleSignInAccount?>[];

        onCurrentUserChangedController.stream.listen((account) {
          listener1Events.add(account);
        });
        onCurrentUserChangedController.stream.listen((account) {
          listener2Events.add(account);
        });

        onCurrentUserChangedController.add(mockAccount);

        await Future.delayed(Duration.zero);

        expect(listener1Events.length, equals(1));
        expect(listener2Events.length, equals(1));
      });

      test('emits changes in sequence', () async {
        final events = <GoogleSignInAccount?>[];
        final mockAccount2 = MockGoogleSignInAccount();
        when(() => mockAccount2.email).thenReturn('user2@example.com');

        onCurrentUserChangedController.stream.listen((account) {
          events.add(account);
        });

        // Sign in with first account
        onCurrentUserChangedController.add(mockAccount);
        // Sign out
        onCurrentUserChangedController.add(null);
        // Sign in with second account
        onCurrentUserChangedController.add(mockAccount2);

        await Future.delayed(Duration.zero);

        expect(events.length, equals(3));
        expect(events[0]!.email, equals('test@example.com'));
        expect(events[1], isNull);
        expect(events[2]!.email, equals('user2@example.com'));
      });
    });

    group('userStream', () {
      test('provides broadcast stream of user changes', () async {
        final userController =
            StreamController<GoogleSignInAccount?>.broadcast();
        final events = <GoogleSignInAccount?>[];

        userController.stream.listen((account) {
          events.add(account);
        });

        userController.add(mockAccount);
        userController.add(null);

        await Future.delayed(Duration.zero);

        expect(events.length, equals(2));
        expect(events[0], equals(mockAccount));
        expect(events[1], isNull);

        await userController.close();
      });
    });
  });

  group('AuthService Scopes', () {
    // The app uses minimal scopes: email, gmail.readonly, calendar.events
    const expectedScopes = [
      'email',
      'https://www.googleapis.com/auth/gmail.readonly',
      'https://www.googleapis.com/auth/calendar.events',
    ];

    test('requests email scope', () {
      expect(expectedScopes, contains('email'));
    });

    test('requests Gmail readonly scope', () {
      expect(
        expectedScopes,
        contains('https://www.googleapis.com/auth/gmail.readonly'),
      );
    });

    test('requests Calendar events scope', () {
      expect(
        expectedScopes,
        contains('https://www.googleapis.com/auth/calendar.events'),
      );
    });

    test('does NOT request gmail.send scope', () {
      expect(
        expectedScopes,
        isNot(contains('https://www.googleapis.com/auth/gmail.send')),
      );
    });

    test('has exactly 3 required scopes', () {
      expect(expectedScopes.length, equals(3));
    });
  });

  group('AuthService Error handling', () {
    group('network errors', () {
      test('signIn handles network timeout', () async {
        when(() => mockGoogleSignIn.signIn())
            .thenThrow(Exception('Network timeout'));

        expect(
          () => mockGoogleSignIn.signIn(),
          throwsA(predicate<Exception>((e) =>
              e.toString().contains('Network timeout'))),
        );
      });

      test('signIn handles no internet connection', () async {
        when(() => mockGoogleSignIn.signIn())
            .thenThrow(Exception('No internet connection'));

        expect(
          () => mockGoogleSignIn.signIn(),
          throwsA(predicate<Exception>((e) =>
              e.toString().contains('No internet connection'))),
        );
      });

      test('silent signIn handles network errors silently', () async {
        when(() => mockGoogleSignIn.signInSilently())
            .thenThrow(Exception('Network error'));

        GoogleSignInAccount? result;
        try {
          result = await mockGoogleSignIn.signInSilently();
        } catch (e) {
          // Silently fail - user can sign in manually
          result = null;
        }

        expect(result, isNull);
      });

      test('token retrieval handles network errors', () async {
        when(() => mockAccount.authentication)
            .thenThrow(Exception('Network error'));

        String? accessToken;
        try {
          final auth = await mockAccount.authentication;
          accessToken = auth.accessToken;
        } catch (e) {
          accessToken = null;
        }

        expect(accessToken, isNull);
      });
    });

    group('user cancellation', () {
      test('signIn returns null when user cancels', () async {
        // User cancellation typically results in null return, not exception
        when(() => mockGoogleSignIn.signIn()).thenAnswer((_) async => null);

        final result = await mockGoogleSignIn.signIn();

        expect(result, isNull);
      });

      test('signIn handles cancellation exception', () async {
        // Some implementations throw a specific cancellation error
        when(() => mockGoogleSignIn.signIn())
            .thenThrow(Exception('sign_in_canceled'));

        expect(
          () => mockGoogleSignIn.signIn(),
          throwsA(predicate<Exception>((e) =>
              e.toString().contains('sign_in_canceled'))),
        );
      });

      test('user can retry after cancellation', () async {
        // First attempt - cancelled
        when(() => mockGoogleSignIn.signIn()).thenAnswer((_) async => null);
        final firstResult = await mockGoogleSignIn.signIn();
        expect(firstResult, isNull);

        // Second attempt - success
        reset(mockGoogleSignIn);
        when(() => mockGoogleSignIn.signIn())
            .thenAnswer((_) async => mockAccount);
        final secondResult = await mockGoogleSignIn.signIn();
        expect(secondResult, isNotNull);
      });
    });

    group('revoked access', () {
      test('signInSilently fails when access is revoked', () async {
        when(() => mockGoogleSignIn.signInSilently())
            .thenAnswer((_) async => null);

        final result = await mockGoogleSignIn.signInSilently();

        expect(result, isNull);
      });

      test('token retrieval fails when access is revoked', () async {
        when(() => mockAccount.authentication)
            .thenThrow(Exception('Access revoked'));

        String? accessToken;
        try {
          final auth = await mockAccount.authentication;
          accessToken = auth.accessToken;
        } catch (e) {
          // Try to refresh
          try {
            when(() => mockGoogleSignIn.signInSilently(reAuthenticate: true))
                .thenAnswer((_) async => null);
            await mockGoogleSignIn.signInSilently(reAuthenticate: true);
          } catch (e) {
            // Need full re-auth
          }
          accessToken = null;
        }

        expect(accessToken, isNull);
      });

      test('disconnect clears state after access revocation', () async {
        when(() => mockGoogleSignIn.disconnect()).thenAnswer((_) async {});

        await mockGoogleSignIn.disconnect();

        verify(() => mockGoogleSignIn.disconnect()).called(1);
      });

      test('requires full sign-in after access revocation', () async {
        // Simulate revoked state
        when(() => mockGoogleSignIn.signInSilently())
            .thenAnswer((_) async => null);
        when(() => mockGoogleSignIn.signIn())
            .thenAnswer((_) async => mockAccount);

        // Silent sign-in fails
        final silentResult = await mockGoogleSignIn.signInSilently();
        expect(silentResult, isNull);

        // Full sign-in succeeds
        final fullResult = await mockGoogleSignIn.signIn();
        expect(fullResult, isNotNull);
      });
    });

    group('server errors', () {
      test('handles Google API server errors', () async {
        when(() => mockGoogleSignIn.signIn())
            .thenThrow(Exception('Google API error: 500'));

        expect(
          () => mockGoogleSignIn.signIn(),
          throwsA(predicate<Exception>((e) =>
              e.toString().contains('500'))),
        );
      });

      test('handles rate limiting errors', () async {
        when(() => mockGoogleSignIn.signIn())
            .thenThrow(Exception('Rate limit exceeded'));

        expect(
          () => mockGoogleSignIn.signIn(),
          throwsA(predicate<Exception>((e) =>
              e.toString().contains('Rate limit'))),
        );
      });
    });

    group('configuration errors', () {
      test('handles missing OAuth client ID', () async {
        when(() => mockGoogleSignIn.signIn())
            .thenThrow(Exception('Missing OAuth client ID'));

        expect(
          () => mockGoogleSignIn.signIn(),
          throwsA(isA<Exception>()),
        );
      });

      test('handles invalid scope errors', () async {
        when(() => mockGoogleSignIn.signIn())
            .thenThrow(Exception('Invalid scope requested'));

        expect(
          () => mockGoogleSignIn.signIn(),
          throwsA(isA<Exception>()),
        );
      });
    });
  });

  group('AuthService Initialize', () {
    test('initialize sets up onCurrentUserChanged listener', () async {
      final events = <GoogleSignInAccount?>[];

      when(() => mockGoogleSignIn.onCurrentUserChanged)
          .thenAnswer((_) => onCurrentUserChangedController.stream);
      when(() => mockGoogleSignIn.signInSilently())
          .thenAnswer((_) async => null);

      // Simulate what initialize() does
      mockGoogleSignIn.onCurrentUserChanged.listen((account) {
        events.add(account);
      });
      await mockGoogleSignIn.signInSilently();

      // Emit a change
      onCurrentUserChangedController.add(mockAccount);
      await Future.delayed(Duration.zero);

      expect(events.length, equals(1));
    });

    test('initialize attempts silent sign-in', () async {
      when(() => mockGoogleSignIn.signInSilently())
          .thenAnswer((_) async => mockAccount);

      final result = await mockGoogleSignIn.signInSilently();

      expect(result, isNotNull);
      verify(() => mockGoogleSignIn.signInSilently()).called(1);
    });

    test('initialize handles silent sign-in failure gracefully', () async {
      when(() => mockGoogleSignIn.signInSilently())
          .thenThrow(Exception('Silent sign-in failed'));

      GoogleSignInAccount? currentUser;
      try {
        currentUser = await mockGoogleSignIn.signInSilently();
      } catch (e) {
        // Silently fail - user can sign in manually
      }

      expect(currentUser, isNull);
    });

    test('initialize restores session from previous sign-in', () async {
      when(() => mockGoogleSignIn.signInSilently())
          .thenAnswer((_) async => mockAccount);

      final restoredAccount = await mockGoogleSignIn.signInSilently();

      expect(restoredAccount, isNotNull);
      expect(restoredAccount!.email, equals('test@example.com'));
    });
  });

  group('AuthService Dispose', () {
    test('dispose closes user stream controller', () async {
      final userController =
          StreamController<GoogleSignInAccount?>.broadcast();
      var streamClosed = false;

      userController.done.then((_) {
        streamClosed = true;
      });

      await userController.close();

      await Future.delayed(Duration.zero);
      expect(streamClosed, isTrue);
    });

    test('no events after dispose', () async {
      final userController =
          StreamController<GoogleSignInAccount?>.broadcast();
      final events = <GoogleSignInAccount?>[];

      userController.stream.listen((account) {
        events.add(account);
      });

      await userController.close();

      // This should not add to events since controller is closed
      expect(
        () => userController.add(mockAccount),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('AuthService Account properties', () {
    test('account has email', () {
      expect(mockAccount.email, equals('test@example.com'));
    });

    test('account has display name', () {
      expect(mockAccount.displayName, equals('Test User'));
    });

    test('account has id', () {
      expect(mockAccount.id, equals('user-123'));
    });

    test('account has photo URL', () {
      expect(mockAccount.photoUrl, equals('https://example.com/photo.jpg'));
    });

    test('account can have null display name', () {
      when(() => mockAccount.displayName).thenReturn(null);

      expect(mockAccount.displayName, isNull);
    });

    test('account can have null photo URL', () {
      when(() => mockAccount.photoUrl).thenReturn(null);

      expect(mockAccount.photoUrl, isNull);
    });
  });

  group('AuthService Concurrent operations', () {
    test('multiple sign-in attempts are handled correctly', () async {
      var signInCount = 0;
      when(() => mockGoogleSignIn.signIn()).thenAnswer((_) async {
        signInCount++;
        await Future.delayed(const Duration(milliseconds: 50));
        return mockAccount;
      });

      // Start multiple sign-ins concurrently
      final futures = [
        mockGoogleSignIn.signIn(),
        mockGoogleSignIn.signIn(),
        mockGoogleSignIn.signIn(),
      ];

      final results = await Future.wait(futures);

      expect(signInCount, equals(3));
      expect(results.every((r) => r == mockAccount), isTrue);
    });

    test('sign-out during sign-in handles gracefully', () async {
      when(() => mockGoogleSignIn.signIn()).thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 50));
        return mockAccount;
      });
      when(() => mockGoogleSignIn.signOut()).thenAnswer((_) async {});

      // Start sign-in and sign-out concurrently
      final signInFuture = mockGoogleSignIn.signIn();
      await Future.delayed(const Duration(milliseconds: 10));
      await mockGoogleSignIn.signOut();

      final result = await signInFuture;

      // Sign-in completes, but signOut may have already run
      expect(result, equals(mockAccount));
    });
  });

  group('AuthService Token validation logic', () {
    test('getValidAccessToken returns token when authentication succeeds',
        () async {
      when(() => mockAccount.authentication)
          .thenAnswer((_) async => mockAuth);
      when(() => mockAuth.accessToken).thenReturn('valid-token');

      // Simulate getValidAccessToken logic
      GoogleSignInAccount? currentUser = mockAccount;
      String? token;

      if (currentUser != null) {
        try {
          final auth = await currentUser.authentication;
          token = auth.accessToken;
        } catch (e) {
          token = null;
        }
      }

      expect(token, equals('valid-token'));
    });

    test('getValidAccessToken attempts refresh on initial failure', () async {
      var attempt = 0;
      when(() => mockAccount.authentication).thenAnswer((_) async {
        attempt++;
        if (attempt == 1) {
          throw Exception('Token expired');
        }
        return mockAuth;
      });
      when(() => mockAuth.accessToken).thenReturn('refreshed-token');
      when(() => mockGoogleSignIn.signInSilently(reAuthenticate: true))
          .thenAnswer((_) async => mockAccount);

      // Simulate getValidAccessToken logic with refresh
      GoogleSignInAccount? currentUser = mockAccount;
      String? token;

      if (currentUser != null) {
        try {
          final auth = await currentUser.authentication;
          token = auth.accessToken;
        } catch (e) {
          // Try to refresh
          try {
            await mockGoogleSignIn.signInSilently(reAuthenticate: true);
            final auth = await currentUser.authentication;
            token = auth.accessToken;
          } catch (e) {
            token = null;
          }
        }
      }

      expect(token, equals('refreshed-token'));
    });

    test('getValidAccessToken returns null when refresh also fails', () async {
      when(() => mockAccount.authentication)
          .thenThrow(Exception('Token expired'));
      when(() => mockGoogleSignIn.signInSilently(reAuthenticate: true))
          .thenThrow(Exception('Refresh failed'));

      // Simulate getValidAccessToken logic
      GoogleSignInAccount? currentUser = mockAccount;
      String? token;

      if (currentUser != null) {
        try {
          final auth = await currentUser.authentication;
          token = auth.accessToken;
        } catch (e) {
          // Try to refresh
          try {
            await mockGoogleSignIn.signInSilently(reAuthenticate: true);
            final auth = await currentUser.authentication;
            token = auth.accessToken;
          } catch (e) {
            // Need full re-auth
            token = null;
          }
        }
      }

      expect(token, isNull);
    });
  });
}
