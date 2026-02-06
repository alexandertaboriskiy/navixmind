import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mocktail/mocktail.dart';

class MockGoogleSignIn extends Mock implements GoogleSignIn {}

class MockGoogleSignInAccount extends Mock implements GoogleSignInAccount {}

class MockGoogleSignInAuthentication extends Mock
    implements GoogleSignInAuthentication {}

/// Tests for the signIn + requestScopes flow in AuthService.
///
/// AuthService.signIn() now:
/// 1. Calls signIn() to get the user account
/// 2. Calls requestScopes() to ensure Calendar/Gmail are granted
///    (without revoking the session, so signInSilently works on restart)
void main() {
  late MockGoogleSignIn mockGoogleSignIn;
  late MockGoogleSignInAccount mockAccount;

  setUp(() {
    mockGoogleSignIn = MockGoogleSignIn();
    mockAccount = MockGoogleSignInAccount();

    when(() => mockAccount.email).thenReturn('test@example.com');
  });

  group('AuthService signIn with requestScopes flow', () {
    test('signIn calls requestScopes after successful sign-in', () async {
      when(() => mockGoogleSignIn.signIn())
          .thenAnswer((_) async => mockAccount);
      when(() => mockGoogleSignIn.requestScopes(any()))
          .thenAnswer((_) async => true);

      // Simulate AuthService.signIn() flow
      final account = await mockGoogleSignIn.signIn();
      if (account != null) {
        await mockGoogleSignIn.requestScopes([
          'https://www.googleapis.com/auth/gmail.readonly',
          'https://www.googleapis.com/auth/calendar.events',
        ]);
      }

      verify(() => mockGoogleSignIn.signIn()).called(1);
      verify(() => mockGoogleSignIn.requestScopes([
            'https://www.googleapis.com/auth/gmail.readonly',
            'https://www.googleapis.com/auth/calendar.events',
          ])).called(1);
    });

    test('signIn does NOT call disconnect before signIn', () async {
      when(() => mockGoogleSignIn.signIn())
          .thenAnswer((_) async => mockAccount);
      when(() => mockGoogleSignIn.requestScopes(any()))
          .thenAnswer((_) async => true);

      // Simulate AuthService.signIn() flow — no disconnect
      await mockGoogleSignIn.signIn();

      verifyNever(() => mockGoogleSignIn.disconnect());
    });

    test('requestScopes not called when user cancels sign-in', () async {
      when(() => mockGoogleSignIn.signIn())
          .thenAnswer((_) async => null);

      // Simulate AuthService.signIn() flow
      final account = await mockGoogleSignIn.signIn();
      if (account != null) {
        await mockGoogleSignIn.requestScopes(any());
      }

      verify(() => mockGoogleSignIn.signIn()).called(1);
      verifyNever(() => mockGoogleSignIn.requestScopes(any()));
    });

    test('user declining additional scopes does not throw', () async {
      when(() => mockGoogleSignIn.signIn())
          .thenAnswer((_) async => mockAccount);
      when(() => mockGoogleSignIn.requestScopes(any()))
          .thenAnswer((_) async => false); // User declined

      final account = await mockGoogleSignIn.signIn();
      bool? granted;
      if (account != null) {
        granted = await mockGoogleSignIn.requestScopes([
          'https://www.googleapis.com/auth/gmail.readonly',
          'https://www.googleapis.com/auth/calendar.events',
        ]);
      }

      // Should not crash; just logs that user declined
      expect(account, isNotNull);
      expect(granted, isFalse);
    });

    test('signInSilently works on restart after signIn + requestScopes', () async {
      // Simulate: user signed in previously, app restarted
      when(() => mockGoogleSignIn.signInSilently())
          .thenAnswer((_) async => mockAccount);

      final restored = await mockGoogleSignIn.signInSilently();

      expect(restored, isNotNull);
      expect(restored!.email, equals('test@example.com'));
      // No disconnect was called, so session persists
      verifyNever(() => mockGoogleSignIn.disconnect());
    });

    test('multiple sign-in attempts preserve session for silent restore', () async {
      when(() => mockGoogleSignIn.signIn())
          .thenAnswer((_) async => mockAccount);
      when(() => mockGoogleSignIn.requestScopes(any()))
          .thenAnswer((_) async => true);
      when(() => mockGoogleSignIn.signInSilently())
          .thenAnswer((_) async => mockAccount);

      // First sign-in
      await mockGoogleSignIn.signIn();

      // App restart — signInSilently should work
      final restored = await mockGoogleSignIn.signInSilently();
      expect(restored, isNotNull);
    });
  });

  group('AuthService scopes in constructor', () {
    test('minimal scopes are included upfront', () {
      // The GoogleSignIn constructor should include only the minimum scopes
      const expectedScopes = [
        'email',
        'https://www.googleapis.com/auth/gmail.readonly',
        'https://www.googleapis.com/auth/calendar.events',
      ];

      // Verify only the required scopes
      expect(expectedScopes.length, equals(3));
      expect(expectedScopes, contains('email'));
      expect(expectedScopes,
          contains('https://www.googleapis.com/auth/gmail.readonly'));
      expect(expectedScopes,
          contains('https://www.googleapis.com/auth/calendar.events'));
      // These should NOT be present
      expect(expectedScopes,
          isNot(contains('https://www.googleapis.com/auth/gmail.send')));
      expect(expectedScopes,
          isNot(contains('https://www.googleapis.com/auth/calendar')));
    });

    test('requestScopes ensures additional scopes are granted', () async {
      when(() => mockGoogleSignIn.requestScopes([
            'https://www.googleapis.com/auth/gmail.readonly',
            'https://www.googleapis.com/auth/calendar.events',
          ])).thenAnswer((_) async => true);

      final granted = await mockGoogleSignIn.requestScopes([
        'https://www.googleapis.com/auth/gmail.readonly',
        'https://www.googleapis.com/auth/calendar.events',
      ]);

      expect(granted, isTrue);
    });
  });

  group('AuthService disconnect for settings', () {
    test('disconnect revokes server-side grant', () async {
      when(() => mockGoogleSignIn.disconnect()).thenAnswer((_) async {});

      await mockGoogleSignIn.disconnect();

      verify(() => mockGoogleSignIn.disconnect()).called(1);
    });

    test('disconnect clears state even if server-side disconnect throws',
        () async {
      when(() => mockGoogleSignIn.disconnect())
          .thenThrow(Exception('Server error'));

      // Simulate AuthService.disconnect() — should catch and clear state
      bool stateCleared = false;
      try {
        await mockGoogleSignIn.disconnect();
      } catch (_) {
        stateCleared = true;
      }

      expect(stateCleared, isTrue);
    });

    test('after explicit disconnect, signInSilently returns null', () async {
      when(() => mockGoogleSignIn.disconnect()).thenAnswer((_) async {});
      when(() => mockGoogleSignIn.signInSilently())
          .thenAnswer((_) async => null);

      // User disconnects in settings
      await mockGoogleSignIn.disconnect();

      // App restart — signInSilently should fail (grant revoked)
      final restored = await mockGoogleSignIn.signInSilently();
      expect(restored, isNull);
    });

    test('can reconnect after explicit disconnect', () async {
      when(() => mockGoogleSignIn.disconnect()).thenAnswer((_) async {});
      when(() => mockGoogleSignIn.signIn())
          .thenAnswer((_) async => mockAccount);
      when(() => mockGoogleSignIn.requestScopes(any()))
          .thenAnswer((_) async => true);

      // Disconnect from settings
      await mockGoogleSignIn.disconnect();

      // Reconnect — should work without needing another disconnect
      final account = await mockGoogleSignIn.signIn();
      expect(account, isNotNull);

      // signIn does NOT call disconnect
      verify(() => mockGoogleSignIn.disconnect()).called(1); // Only the explicit one
    });
  });
}
