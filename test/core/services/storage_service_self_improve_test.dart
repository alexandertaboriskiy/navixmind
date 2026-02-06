import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

/// Testable version for self-improve toggle
class TestableSelfImproveStorage {
  final FlutterSecureStorage _storage;

  TestableSelfImproveStorage(this._storage);

  static const _keySelfImproveEnabled = 'self_improve_enabled';

  Future<void> setSelfImproveEnabled(bool enabled) async {
    await _storage.write(key: _keySelfImproveEnabled, value: enabled.toString());
  }

  Future<bool> isSelfImproveEnabled() async {
    final value = await _storage.read(key: _keySelfImproveEnabled);
    return value == 'true';
  }
}

void main() {
  late MockFlutterSecureStorage mockStorage;
  late TestableSelfImproveStorage storageService;

  setUp(() {
    mockStorage = MockFlutterSecureStorage();
    storageService = TestableSelfImproveStorage(mockStorage);
  });

  group('StorageService Self Improve', () {
    group('isSelfImproveEnabled', () {
      test('defaults to false when no value stored', () async {
        when(() => mockStorage.read(key: 'self_improve_enabled'))
            .thenAnswer((_) async => null);

        final result = await storageService.isSelfImproveEnabled();

        expect(result, isFalse);
      });

      test('returns false when stored value is empty string', () async {
        when(() => mockStorage.read(key: 'self_improve_enabled'))
            .thenAnswer((_) async => '');

        final result = await storageService.isSelfImproveEnabled();

        expect(result, isFalse);
      });

      test('returns true when stored value is "true"', () async {
        when(() => mockStorage.read(key: 'self_improve_enabled'))
            .thenAnswer((_) async => 'true');

        final result = await storageService.isSelfImproveEnabled();

        expect(result, isTrue);
      });

      test('returns false when stored value is "false"', () async {
        when(() => mockStorage.read(key: 'self_improve_enabled'))
            .thenAnswer((_) async => 'false');

        final result = await storageService.isSelfImproveEnabled();

        expect(result, isFalse);
      });

      test('returns false when stored value is "True" (case-sensitive)', () async {
        when(() => mockStorage.read(key: 'self_improve_enabled'))
            .thenAnswer((_) async => 'True');

        final result = await storageService.isSelfImproveEnabled();

        // value == 'true' is case-sensitive, so 'True' returns false
        expect(result, isFalse);
      });

      test('returns false when stored value is "1"', () async {
        when(() => mockStorage.read(key: 'self_improve_enabled'))
            .thenAnswer((_) async => '1');

        final result = await storageService.isSelfImproveEnabled();

        expect(result, isFalse);
      });

      test('returns false for any non-"true" string', () async {
        when(() => mockStorage.read(key: 'self_improve_enabled'))
            .thenAnswer((_) async => 'random-value');

        final result = await storageService.isSelfImproveEnabled();

        expect(result, isFalse);
      });
    });

    group('setSelfImproveEnabled', () {
      test('stores true as "true"', () async {
        when(() => mockStorage.write(
              key: 'self_improve_enabled',
              value: 'true',
            )).thenAnswer((_) async {});

        await storageService.setSelfImproveEnabled(true);

        verify(() => mockStorage.write(
              key: 'self_improve_enabled',
              value: 'true',
            )).called(1);
      });

      test('stores false as "false"', () async {
        when(() => mockStorage.write(
              key: 'self_improve_enabled',
              value: 'false',
            )).thenAnswer((_) async {});

        await storageService.setSelfImproveEnabled(false);

        verify(() => mockStorage.write(
              key: 'self_improve_enabled',
              value: 'false',
            )).called(1);
      });

      test('can toggle true then false', () async {
        when(() => mockStorage.write(
              key: 'self_improve_enabled',
              value: any(named: 'value'),
            )).thenAnswer((_) async {});

        await storageService.setSelfImproveEnabled(true);
        await storageService.setSelfImproveEnabled(false);

        verify(() => mockStorage.write(
              key: 'self_improve_enabled',
              value: 'true',
            )).called(1);
        verify(() => mockStorage.write(
              key: 'self_improve_enabled',
              value: 'false',
            )).called(1);
      });
    });

    group('set then get workflow', () {
      test('set true then read returns true', () async {
        when(() => mockStorage.write(
              key: 'self_improve_enabled',
              value: 'true',
            )).thenAnswer((_) async {});
        when(() => mockStorage.read(key: 'self_improve_enabled'))
            .thenAnswer((_) async => 'true');

        await storageService.setSelfImproveEnabled(true);
        final result = await storageService.isSelfImproveEnabled();

        expect(result, isTrue);
      });

      test('set false then read returns false', () async {
        when(() => mockStorage.write(
              key: 'self_improve_enabled',
              value: 'false',
            )).thenAnswer((_) async {});
        when(() => mockStorage.read(key: 'self_improve_enabled'))
            .thenAnswer((_) async => 'false');

        await storageService.setSelfImproveEnabled(false);
        final result = await storageService.isSelfImproveEnabled();

        expect(result, isFalse);
      });
    });

    group('error handling', () {
      test('write throws propagates exception', () async {
        when(() => mockStorage.write(
              key: 'self_improve_enabled',
              value: any(named: 'value'),
            )).thenThrow(Exception('Storage write failed'));

        expect(
          () => storageService.setSelfImproveEnabled(true),
          throwsA(isA<Exception>()),
        );
      });

      test('read throws propagates exception', () async {
        when(() => mockStorage.read(key: 'self_improve_enabled'))
            .thenThrow(Exception('Storage read failed'));

        expect(
          () => storageService.isSelfImproveEnabled(),
          throwsA(isA<Exception>()),
        );
      });
    });
  });
}
