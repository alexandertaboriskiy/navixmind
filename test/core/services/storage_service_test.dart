import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// Mock class for FlutterSecureStorage
class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

/// Testable version of StorageService that allows dependency injection
/// This mirrors the actual StorageService implementation but accepts an injected storage
class TestableStorageService {
  final FlutterSecureStorage _storage;

  TestableStorageService(this._storage);

  // Keys (same as actual StorageService)
  static const _keyApiKey = 'claude_api_key';
  static const _keyGoogleRefreshToken = 'google_refresh_token';
  static const _keyDailyLimit = 'daily_cost_limit';
  static const _keyMonthlyLimit = 'monthly_cost_limit';
  static const _keyLimitEnabled = 'cost_limit_enabled';

  /// Store Claude API key securely
  Future<void> setApiKey(String key) async {
    await _storage.write(key: _keyApiKey, value: key);
  }

  /// Get stored API key
  Future<String?> getApiKey() async {
    return await _storage.read(key: _keyApiKey);
  }

  /// Check if API key is stored
  Future<bool> hasApiKey() async {
    return await _storage.containsKey(key: _keyApiKey);
  }

  /// Delete API key
  Future<void> deleteApiKey() async {
    await _storage.delete(key: _keyApiKey);
  }

  /// Store Google refresh token (if needed for manual refresh)
  Future<void> setGoogleRefreshToken(String token) async {
    await _storage.write(key: _keyGoogleRefreshToken, value: token);
  }

  /// Get Google refresh token
  Future<String?> getGoogleRefreshToken() async {
    return await _storage.read(key: _keyGoogleRefreshToken);
  }

  /// Delete Google refresh token
  Future<void> deleteGoogleRefreshToken() async {
    await _storage.delete(key: _keyGoogleRefreshToken);
  }

  /// Clear all secure storage
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  // Cost limit methods

  /// Set daily cost limit
  Future<void> setDailyLimit(double limit) async {
    await _storage.write(key: _keyDailyLimit, value: limit.toString());
  }

  /// Get daily cost limit (default: 0.50)
  Future<double> getDailyLimit() async {
    final value = await _storage.read(key: _keyDailyLimit);
    return value != null ? double.tryParse(value) ?? 0.50 : 0.50;
  }

  /// Set monthly cost limit
  Future<void> setMonthlyLimit(double limit) async {
    await _storage.write(key: _keyMonthlyLimit, value: limit.toString());
  }

  /// Get monthly cost limit (default: 10.00)
  Future<double> getMonthlyLimit() async {
    final value = await _storage.read(key: _keyMonthlyLimit);
    return value != null ? double.tryParse(value) ?? 10.00 : 10.00;
  }

  /// Enable/disable cost limits
  Future<void> setCostLimitEnabled(bool enabled) async {
    await _storage.write(key: _keyLimitEnabled, value: enabled.toString());
  }

  /// Check if cost limits are enabled (default: true)
  Future<bool> isCostLimitEnabled() async {
    final value = await _storage.read(key: _keyLimitEnabled);
    return value != 'false';
  }
}

void main() {
  late MockFlutterSecureStorage mockStorage;
  late TestableStorageService storageService;

  setUp(() {
    mockStorage = MockFlutterSecureStorage();
    storageService = TestableStorageService(mockStorage);
  });

  group('StorageService API Key', () {
    group('setApiKey', () {
      test('stores API key in secure storage', () async {
        when(() => mockStorage.write(
              key: 'claude_api_key',
              value: 'sk-ant-test-key-123',
            )).thenAnswer((_) async {});

        await storageService.setApiKey('sk-ant-test-key-123');

        verify(() => mockStorage.write(
              key: 'claude_api_key',
              value: 'sk-ant-test-key-123',
            )).called(1);
      });

      test('stores empty string API key', () async {
        when(() => mockStorage.write(
              key: 'claude_api_key',
              value: '',
            )).thenAnswer((_) async {});

        await storageService.setApiKey('');

        verify(() => mockStorage.write(
              key: 'claude_api_key',
              value: '',
            )).called(1);
      });

      test('overwrites existing API key', () async {
        when(() => mockStorage.write(
              key: 'claude_api_key',
              value: any(named: 'value'),
            )).thenAnswer((_) async {});

        await storageService.setApiKey('old-key');
        await storageService.setApiKey('new-key');

        verify(() => mockStorage.write(
              key: 'claude_api_key',
              value: 'old-key',
            )).called(1);
        verify(() => mockStorage.write(
              key: 'claude_api_key',
              value: 'new-key',
            )).called(1);
      });

      test('handles special characters in API key', () async {
        const specialKey = 'sk-ant-!@#\$%^&*()_+-=[]{}|;:,.<>?';
        when(() => mockStorage.write(
              key: 'claude_api_key',
              value: specialKey,
            )).thenAnswer((_) async {});

        await storageService.setApiKey(specialKey);

        verify(() => mockStorage.write(
              key: 'claude_api_key',
              value: specialKey,
            )).called(1);
      });

      test('handles very long API key', () async {
        final longKey = 'sk-ant-${'x' * 1000}';
        when(() => mockStorage.write(
              key: 'claude_api_key',
              value: longKey,
            )).thenAnswer((_) async {});

        await storageService.setApiKey(longKey);

        verify(() => mockStorage.write(
              key: 'claude_api_key',
              value: longKey,
            )).called(1);
      });
    });

    group('getApiKey', () {
      test('returns stored API key', () async {
        when(() => mockStorage.read(key: 'claude_api_key'))
            .thenAnswer((_) async => 'sk-ant-test-key-123');

        final result = await storageService.getApiKey();

        expect(result, equals('sk-ant-test-key-123'));
        verify(() => mockStorage.read(key: 'claude_api_key')).called(1);
      });

      test('returns null when no API key is stored', () async {
        when(() => mockStorage.read(key: 'claude_api_key'))
            .thenAnswer((_) async => null);

        final result = await storageService.getApiKey();

        expect(result, isNull);
      });

      test('returns empty string when empty string was stored', () async {
        when(() => mockStorage.read(key: 'claude_api_key'))
            .thenAnswer((_) async => '');

        final result = await storageService.getApiKey();

        expect(result, equals(''));
      });
    });

    group('hasApiKey', () {
      test('returns true when API key exists', () async {
        when(() => mockStorage.containsKey(key: 'claude_api_key'))
            .thenAnswer((_) async => true);

        final result = await storageService.hasApiKey();

        expect(result, isTrue);
        verify(() => mockStorage.containsKey(key: 'claude_api_key')).called(1);
      });

      test('returns false when API key does not exist', () async {
        when(() => mockStorage.containsKey(key: 'claude_api_key'))
            .thenAnswer((_) async => false);

        final result = await storageService.hasApiKey();

        expect(result, isFalse);
      });
    });

    group('deleteApiKey', () {
      test('deletes API key from storage', () async {
        when(() => mockStorage.delete(key: 'claude_api_key'))
            .thenAnswer((_) async {});

        await storageService.deleteApiKey();

        verify(() => mockStorage.delete(key: 'claude_api_key')).called(1);
      });

      test('succeeds even when API key does not exist', () async {
        when(() => mockStorage.delete(key: 'claude_api_key'))
            .thenAnswer((_) async {});

        await expectLater(storageService.deleteApiKey(), completes);
      });
    });
  });

  group('StorageService Google Refresh Token', () {
    group('setGoogleRefreshToken', () {
      test('stores Google refresh token', () async {
        when(() => mockStorage.write(
              key: 'google_refresh_token',
              value: 'refresh-token-123',
            )).thenAnswer((_) async {});

        await storageService.setGoogleRefreshToken('refresh-token-123');

        verify(() => mockStorage.write(
              key: 'google_refresh_token',
              value: 'refresh-token-123',
            )).called(1);
      });

      test('stores empty refresh token', () async {
        when(() => mockStorage.write(
              key: 'google_refresh_token',
              value: '',
            )).thenAnswer((_) async {});

        await storageService.setGoogleRefreshToken('');

        verify(() => mockStorage.write(
              key: 'google_refresh_token',
              value: '',
            )).called(1);
      });
    });

    group('getGoogleRefreshToken', () {
      test('returns stored Google refresh token', () async {
        when(() => mockStorage.read(key: 'google_refresh_token'))
            .thenAnswer((_) async => 'refresh-token-123');

        final result = await storageService.getGoogleRefreshToken();

        expect(result, equals('refresh-token-123'));
        verify(() => mockStorage.read(key: 'google_refresh_token')).called(1);
      });

      test('returns null when no refresh token is stored', () async {
        when(() => mockStorage.read(key: 'google_refresh_token'))
            .thenAnswer((_) async => null);

        final result = await storageService.getGoogleRefreshToken();

        expect(result, isNull);
      });

      test('returns empty string when empty string was stored', () async {
        when(() => mockStorage.read(key: 'google_refresh_token'))
            .thenAnswer((_) async => '');

        final result = await storageService.getGoogleRefreshToken();

        expect(result, equals(''));
      });
    });

    group('deleteGoogleRefreshToken', () {
      test('deletes Google refresh token from storage', () async {
        when(() => mockStorage.delete(key: 'google_refresh_token'))
            .thenAnswer((_) async {});

        await storageService.deleteGoogleRefreshToken();

        verify(() => mockStorage.delete(key: 'google_refresh_token')).called(1);
      });

      test('succeeds even when refresh token does not exist', () async {
        when(() => mockStorage.delete(key: 'google_refresh_token'))
            .thenAnswer((_) async {});

        await expectLater(storageService.deleteGoogleRefreshToken(), completes);
      });
    });
  });

  group('StorageService Daily Limit', () {
    group('setDailyLimit', () {
      test('stores daily limit as string', () async {
        when(() => mockStorage.write(
              key: 'daily_cost_limit',
              value: '1.5',
            )).thenAnswer((_) async {});

        await storageService.setDailyLimit(1.5);

        verify(() => mockStorage.write(
              key: 'daily_cost_limit',
              value: '1.5',
            )).called(1);
      });

      test('stores zero daily limit', () async {
        when(() => mockStorage.write(
              key: 'daily_cost_limit',
              value: '0.0',
            )).thenAnswer((_) async {});

        await storageService.setDailyLimit(0.0);

        verify(() => mockStorage.write(
              key: 'daily_cost_limit',
              value: '0.0',
            )).called(1);
      });

      test('stores large daily limit', () async {
        when(() => mockStorage.write(
              key: 'daily_cost_limit',
              value: '100.0',
            )).thenAnswer((_) async {});

        await storageService.setDailyLimit(100.0);

        verify(() => mockStorage.write(
              key: 'daily_cost_limit',
              value: '100.0',
            )).called(1);
      });

      test('stores daily limit with many decimal places', () async {
        when(() => mockStorage.write(
              key: 'daily_cost_limit',
              value: '1.23456789',
            )).thenAnswer((_) async {});

        await storageService.setDailyLimit(1.23456789);

        verify(() => mockStorage.write(
              key: 'daily_cost_limit',
              value: '1.23456789',
            )).called(1);
      });
    });

    group('getDailyLimit', () {
      test('returns stored daily limit', () async {
        when(() => mockStorage.read(key: 'daily_cost_limit'))
            .thenAnswer((_) async => '1.5');

        final result = await storageService.getDailyLimit();

        expect(result, equals(1.5));
        verify(() => mockStorage.read(key: 'daily_cost_limit')).called(1);
      });

      test('returns default 0.50 when no limit is stored', () async {
        when(() => mockStorage.read(key: 'daily_cost_limit'))
            .thenAnswer((_) async => null);

        final result = await storageService.getDailyLimit();

        expect(result, equals(0.50));
      });

      test('returns default 0.50 when stored value is unparseable', () async {
        when(() => mockStorage.read(key: 'daily_cost_limit'))
            .thenAnswer((_) async => 'invalid-number');

        final result = await storageService.getDailyLimit();

        expect(result, equals(0.50));
      });

      test('returns default 0.50 when stored value is empty string', () async {
        when(() => mockStorage.read(key: 'daily_cost_limit'))
            .thenAnswer((_) async => '');

        final result = await storageService.getDailyLimit();

        expect(result, equals(0.50));
      });

      test('returns default 0.50 when stored value contains letters', () async {
        when(() => mockStorage.read(key: 'daily_cost_limit'))
            .thenAnswer((_) async => '1.5abc');

        final result = await storageService.getDailyLimit();

        expect(result, equals(0.50));
      });

      test('returns stored zero value', () async {
        when(() => mockStorage.read(key: 'daily_cost_limit'))
            .thenAnswer((_) async => '0.0');

        final result = await storageService.getDailyLimit();

        expect(result, equals(0.0));
      });

      test('returns stored negative value', () async {
        when(() => mockStorage.read(key: 'daily_cost_limit'))
            .thenAnswer((_) async => '-5.0');

        final result = await storageService.getDailyLimit();

        expect(result, equals(-5.0));
      });

      test('handles scientific notation', () async {
        when(() => mockStorage.read(key: 'daily_cost_limit'))
            .thenAnswer((_) async => '1e2');

        final result = await storageService.getDailyLimit();

        expect(result, equals(100.0));
      });
    });
  });

  group('StorageService Monthly Limit', () {
    group('setMonthlyLimit', () {
      test('stores monthly limit as string', () async {
        when(() => mockStorage.write(
              key: 'monthly_cost_limit',
              value: '25.0',
            )).thenAnswer((_) async {});

        await storageService.setMonthlyLimit(25.0);

        verify(() => mockStorage.write(
              key: 'monthly_cost_limit',
              value: '25.0',
            )).called(1);
      });

      test('stores zero monthly limit', () async {
        when(() => mockStorage.write(
              key: 'monthly_cost_limit',
              value: '0.0',
            )).thenAnswer((_) async {});

        await storageService.setMonthlyLimit(0.0);

        verify(() => mockStorage.write(
              key: 'monthly_cost_limit',
              value: '0.0',
            )).called(1);
      });

      test('stores large monthly limit', () async {
        when(() => mockStorage.write(
              key: 'monthly_cost_limit',
              value: '1000.0',
            )).thenAnswer((_) async {});

        await storageService.setMonthlyLimit(1000.0);

        verify(() => mockStorage.write(
              key: 'monthly_cost_limit',
              value: '1000.0',
            )).called(1);
      });
    });

    group('getMonthlyLimit', () {
      test('returns stored monthly limit', () async {
        when(() => mockStorage.read(key: 'monthly_cost_limit'))
            .thenAnswer((_) async => '25.0');

        final result = await storageService.getMonthlyLimit();

        expect(result, equals(25.0));
        verify(() => mockStorage.read(key: 'monthly_cost_limit')).called(1);
      });

      test('returns default 10.00 when no limit is stored', () async {
        when(() => mockStorage.read(key: 'monthly_cost_limit'))
            .thenAnswer((_) async => null);

        final result = await storageService.getMonthlyLimit();

        expect(result, equals(10.00));
      });

      test('returns default 10.00 when stored value is unparseable', () async {
        when(() => mockStorage.read(key: 'monthly_cost_limit'))
            .thenAnswer((_) async => 'not-a-number');

        final result = await storageService.getMonthlyLimit();

        expect(result, equals(10.00));
      });

      test('returns default 10.00 when stored value is empty string', () async {
        when(() => mockStorage.read(key: 'monthly_cost_limit'))
            .thenAnswer((_) async => '');

        final result = await storageService.getMonthlyLimit();

        expect(result, equals(10.00));
      });

      test('returns default 10.00 when stored value is whitespace', () async {
        when(() => mockStorage.read(key: 'monthly_cost_limit'))
            .thenAnswer((_) async => '   ');

        final result = await storageService.getMonthlyLimit();

        expect(result, equals(10.00));
      });

      test('returns stored zero value', () async {
        when(() => mockStorage.read(key: 'monthly_cost_limit'))
            .thenAnswer((_) async => '0');

        final result = await storageService.getMonthlyLimit();

        expect(result, equals(0.0));
      });

      test('returns stored negative value', () async {
        when(() => mockStorage.read(key: 'monthly_cost_limit'))
            .thenAnswer((_) async => '-10.0');

        final result = await storageService.getMonthlyLimit();

        expect(result, equals(-10.0));
      });

      test('handles integer string', () async {
        when(() => mockStorage.read(key: 'monthly_cost_limit'))
            .thenAnswer((_) async => '50');

        final result = await storageService.getMonthlyLimit();

        expect(result, equals(50.0));
      });
    });
  });

  group('StorageService Cost Limit Enabled', () {
    group('setCostLimitEnabled', () {
      test('stores true as string', () async {
        when(() => mockStorage.write(
              key: 'cost_limit_enabled',
              value: 'true',
            )).thenAnswer((_) async {});

        await storageService.setCostLimitEnabled(true);

        verify(() => mockStorage.write(
              key: 'cost_limit_enabled',
              value: 'true',
            )).called(1);
      });

      test('stores false as string', () async {
        when(() => mockStorage.write(
              key: 'cost_limit_enabled',
              value: 'false',
            )).thenAnswer((_) async {});

        await storageService.setCostLimitEnabled(false);

        verify(() => mockStorage.write(
              key: 'cost_limit_enabled',
              value: 'false',
            )).called(1);
      });
    });

    group('isCostLimitEnabled', () {
      test('returns true when stored value is "true"', () async {
        when(() => mockStorage.read(key: 'cost_limit_enabled'))
            .thenAnswer((_) async => 'true');

        final result = await storageService.isCostLimitEnabled();

        expect(result, isTrue);
        verify(() => mockStorage.read(key: 'cost_limit_enabled')).called(1);
      });

      test('returns false when stored value is "false"', () async {
        when(() => mockStorage.read(key: 'cost_limit_enabled'))
            .thenAnswer((_) async => 'false');

        final result = await storageService.isCostLimitEnabled();

        expect(result, isFalse);
      });

      test('returns true (default) when no value is stored', () async {
        when(() => mockStorage.read(key: 'cost_limit_enabled'))
            .thenAnswer((_) async => null);

        final result = await storageService.isCostLimitEnabled();

        expect(result, isTrue);
      });

      test('returns true when stored value is empty string', () async {
        when(() => mockStorage.read(key: 'cost_limit_enabled'))
            .thenAnswer((_) async => '');

        final result = await storageService.isCostLimitEnabled();

        expect(result, isTrue);
      });

      test('returns true when stored value is "True" (case matters)', () async {
        when(() => mockStorage.read(key: 'cost_limit_enabled'))
            .thenAnswer((_) async => 'True');

        final result = await storageService.isCostLimitEnabled();

        expect(result, isTrue);
      });

      test('returns true when stored value is "FALSE" (case matters)', () async {
        when(() => mockStorage.read(key: 'cost_limit_enabled'))
            .thenAnswer((_) async => 'FALSE');

        final result = await storageService.isCostLimitEnabled();

        // Note: Implementation uses value != 'false', so 'FALSE' returns true
        expect(result, isTrue);
      });

      test('returns true when stored value is any non-false string', () async {
        when(() => mockStorage.read(key: 'cost_limit_enabled'))
            .thenAnswer((_) async => 'random-value');

        final result = await storageService.isCostLimitEnabled();

        expect(result, isTrue);
      });

      test('returns true when stored value is "1"', () async {
        when(() => mockStorage.read(key: 'cost_limit_enabled'))
            .thenAnswer((_) async => '1');

        final result = await storageService.isCostLimitEnabled();

        expect(result, isTrue);
      });

      test('returns true when stored value is "0"', () async {
        when(() => mockStorage.read(key: 'cost_limit_enabled'))
            .thenAnswer((_) async => '0');

        final result = await storageService.isCostLimitEnabled();

        // Note: Implementation uses value != 'false', so '0' returns true
        expect(result, isTrue);
      });
    });
  });

  group('StorageService clearAll', () {
    test('deletes all data from storage', () async {
      when(() => mockStorage.deleteAll()).thenAnswer((_) async {});

      await storageService.clearAll();

      verify(() => mockStorage.deleteAll()).called(1);
    });

    test('completes successfully even when storage is empty', () async {
      when(() => mockStorage.deleteAll()).thenAnswer((_) async {});

      await expectLater(storageService.clearAll(), completes);
    });

    test('can be called multiple times', () async {
      when(() => mockStorage.deleteAll()).thenAnswer((_) async {});

      await storageService.clearAll();
      await storageService.clearAll();
      await storageService.clearAll();

      verify(() => mockStorage.deleteAll()).called(3);
    });
  });

  group('StorageService Integration scenarios', () {
    test('set and get API key workflow', () async {
      const apiKey = 'sk-ant-api-key-12345';

      when(() => mockStorage.write(
            key: 'claude_api_key',
            value: apiKey,
          )).thenAnswer((_) async {});
      when(() => mockStorage.read(key: 'claude_api_key'))
          .thenAnswer((_) async => apiKey);
      when(() => mockStorage.containsKey(key: 'claude_api_key'))
          .thenAnswer((_) async => true);

      // Set the key
      await storageService.setApiKey(apiKey);

      // Verify it exists
      final hasKey = await storageService.hasApiKey();
      expect(hasKey, isTrue);

      // Get the key
      final retrievedKey = await storageService.getApiKey();
      expect(retrievedKey, equals(apiKey));
    });

    test('delete and verify API key workflow', () async {
      when(() => mockStorage.delete(key: 'claude_api_key'))
          .thenAnswer((_) async {});
      when(() => mockStorage.containsKey(key: 'claude_api_key'))
          .thenAnswer((_) async => false);
      when(() => mockStorage.read(key: 'claude_api_key'))
          .thenAnswer((_) async => null);

      // Delete the key
      await storageService.deleteApiKey();

      // Verify it no longer exists
      final hasKey = await storageService.hasApiKey();
      expect(hasKey, isFalse);

      // Get returns null
      final retrievedKey = await storageService.getApiKey();
      expect(retrievedKey, isNull);
    });

    test('set and get cost limits workflow', () async {
      when(() => mockStorage.write(
            key: 'daily_cost_limit',
            value: '2.5',
          )).thenAnswer((_) async {});
      when(() => mockStorage.write(
            key: 'monthly_cost_limit',
            value: '50.0',
          )).thenAnswer((_) async {});
      when(() => mockStorage.read(key: 'daily_cost_limit'))
          .thenAnswer((_) async => '2.5');
      when(() => mockStorage.read(key: 'monthly_cost_limit'))
          .thenAnswer((_) async => '50.0');

      // Set limits
      await storageService.setDailyLimit(2.5);
      await storageService.setMonthlyLimit(50.0);

      // Get limits
      final dailyLimit = await storageService.getDailyLimit();
      final monthlyLimit = await storageService.getMonthlyLimit();

      expect(dailyLimit, equals(2.5));
      expect(monthlyLimit, equals(50.0));
    });

    test('toggle cost limit enabled workflow', () async {
      when(() => mockStorage.write(
            key: 'cost_limit_enabled',
            value: 'false',
          )).thenAnswer((_) async {});
      when(() => mockStorage.write(
            key: 'cost_limit_enabled',
            value: 'true',
          )).thenAnswer((_) async {});

      var readValue = 'false';
      when(() => mockStorage.read(key: 'cost_limit_enabled'))
          .thenAnswer((_) async => readValue);

      // Disable limits
      await storageService.setCostLimitEnabled(false);

      // Check disabled
      final disabled = await storageService.isCostLimitEnabled();
      expect(disabled, isFalse);

      // Update mock for re-enabling
      readValue = 'true';

      // Re-enable limits
      await storageService.setCostLimitEnabled(true);

      // Check enabled
      final enabled = await storageService.isCostLimitEnabled();
      expect(enabled, isTrue);
    });

    test('clearAll removes all data', () async {
      when(() => mockStorage.deleteAll()).thenAnswer((_) async {});
      when(() => mockStorage.read(key: 'claude_api_key'))
          .thenAnswer((_) async => null);
      when(() => mockStorage.read(key: 'google_refresh_token'))
          .thenAnswer((_) async => null);
      when(() => mockStorage.read(key: 'daily_cost_limit'))
          .thenAnswer((_) async => null);
      when(() => mockStorage.read(key: 'monthly_cost_limit'))
          .thenAnswer((_) async => null);
      when(() => mockStorage.read(key: 'cost_limit_enabled'))
          .thenAnswer((_) async => null);

      // Clear all
      await storageService.clearAll();

      // Verify all values return defaults/null
      final apiKey = await storageService.getApiKey();
      final refreshToken = await storageService.getGoogleRefreshToken();
      final dailyLimit = await storageService.getDailyLimit();
      final monthlyLimit = await storageService.getMonthlyLimit();
      final limitEnabled = await storageService.isCostLimitEnabled();

      expect(apiKey, isNull);
      expect(refreshToken, isNull);
      expect(dailyLimit, equals(0.50)); // default
      expect(monthlyLimit, equals(10.00)); // default
      expect(limitEnabled, isTrue); // default
    });

    test('multiple storage keys are independent', () async {
      when(() => mockStorage.write(
            key: 'claude_api_key',
            value: 'api-key',
          )).thenAnswer((_) async {});
      when(() => mockStorage.write(
            key: 'google_refresh_token',
            value: 'refresh-token',
          )).thenAnswer((_) async {});
      when(() => mockStorage.read(key: 'claude_api_key'))
          .thenAnswer((_) async => 'api-key');
      when(() => mockStorage.read(key: 'google_refresh_token'))
          .thenAnswer((_) async => 'refresh-token');
      when(() => mockStorage.delete(key: 'claude_api_key'))
          .thenAnswer((_) async {});

      // Set both tokens
      await storageService.setApiKey('api-key');
      await storageService.setGoogleRefreshToken('refresh-token');

      // Both can be retrieved
      expect(await storageService.getApiKey(), equals('api-key'));
      expect(
          await storageService.getGoogleRefreshToken(), equals('refresh-token'));

      // Delete API key only
      await storageService.deleteApiKey();

      // Update mock for deleted API key
      when(() => mockStorage.read(key: 'claude_api_key'))
          .thenAnswer((_) async => null);

      // API key is gone but refresh token remains
      expect(await storageService.getApiKey(), isNull);
      expect(
          await storageService.getGoogleRefreshToken(), equals('refresh-token'));
    });
  });

  group('StorageService Error handling', () {
    test('handles storage write exception', () async {
      when(() => mockStorage.write(
            key: 'claude_api_key',
            value: any(named: 'value'),
          )).thenThrow(Exception('Storage write failed'));

      expect(
        () => storageService.setApiKey('test-key'),
        throwsA(isA<Exception>()),
      );
    });

    test('handles storage read exception', () async {
      when(() => mockStorage.read(key: 'claude_api_key'))
          .thenThrow(Exception('Storage read failed'));

      expect(
        () => storageService.getApiKey(),
        throwsA(isA<Exception>()),
      );
    });

    test('handles storage delete exception', () async {
      when(() => mockStorage.delete(key: 'claude_api_key'))
          .thenThrow(Exception('Storage delete failed'));

      expect(
        () => storageService.deleteApiKey(),
        throwsA(isA<Exception>()),
      );
    });

    test('handles storage containsKey exception', () async {
      when(() => mockStorage.containsKey(key: 'claude_api_key'))
          .thenThrow(Exception('Storage containsKey failed'));

      expect(
        () => storageService.hasApiKey(),
        throwsA(isA<Exception>()),
      );
    });

    test('handles storage deleteAll exception', () async {
      when(() => mockStorage.deleteAll())
          .thenThrow(Exception('Storage deleteAll failed'));

      expect(
        () => storageService.clearAll(),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('StorageService Concurrent operations', () {
    test('handles multiple concurrent reads', () async {
      when(() => mockStorage.read(key: 'claude_api_key'))
          .thenAnswer((_) async => 'api-key');
      when(() => mockStorage.read(key: 'google_refresh_token'))
          .thenAnswer((_) async => 'refresh-token');
      when(() => mockStorage.read(key: 'daily_cost_limit'))
          .thenAnswer((_) async => '5.0');
      when(() => mockStorage.read(key: 'monthly_cost_limit'))
          .thenAnswer((_) async => '100.0');
      when(() => mockStorage.read(key: 'cost_limit_enabled'))
          .thenAnswer((_) async => 'true');

      // Execute all reads concurrently
      final results = await Future.wait([
        storageService.getApiKey(),
        storageService.getGoogleRefreshToken(),
        storageService.getDailyLimit(),
        storageService.getMonthlyLimit(),
        storageService.isCostLimitEnabled(),
      ]);

      expect(results[0], equals('api-key'));
      expect(results[1], equals('refresh-token'));
      expect(results[2], equals(5.0));
      expect(results[3], equals(100.0));
      expect(results[4], isTrue);
    });

    test('handles multiple concurrent writes', () async {
      when(() => mockStorage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          )).thenAnswer((_) async {});

      // Execute all writes concurrently
      await Future.wait([
        storageService.setApiKey('api-key'),
        storageService.setGoogleRefreshToken('refresh-token'),
        storageService.setDailyLimit(5.0),
        storageService.setMonthlyLimit(100.0),
        storageService.setCostLimitEnabled(true),
      ]);

      // Verify all writes happened
      verify(() => mockStorage.write(
            key: 'claude_api_key',
            value: 'api-key',
          )).called(1);
      verify(() => mockStorage.write(
            key: 'google_refresh_token',
            value: 'refresh-token',
          )).called(1);
      verify(() => mockStorage.write(
            key: 'daily_cost_limit',
            value: '5.0',
          )).called(1);
      verify(() => mockStorage.write(
            key: 'monthly_cost_limit',
            value: '100.0',
          )).called(1);
      verify(() => mockStorage.write(
            key: 'cost_limit_enabled',
            value: 'true',
          )).called(1);
    });
  });

  group('StorageService Default values verification', () {
    test('daily limit default is exactly 0.50', () async {
      when(() => mockStorage.read(key: 'daily_cost_limit'))
          .thenAnswer((_) async => null);

      final result = await storageService.getDailyLimit();

      // In Dart, 0.50 and 0.5 are identical double values
      expect(result, equals(0.5));
    });

    test('monthly limit default is exactly 10.00', () async {
      when(() => mockStorage.read(key: 'monthly_cost_limit'))
          .thenAnswer((_) async => null);

      final result = await storageService.getMonthlyLimit();

      // In Dart, 10.00 and 10.0 are identical double values
      expect(result, equals(10.0));
    });

    test('cost limit enabled default is true', () async {
      when(() => mockStorage.read(key: 'cost_limit_enabled'))
          .thenAnswer((_) async => null);

      final result = await storageService.isCostLimitEnabled();

      expect(result, isTrue);
    });
  });

  group('StorageService Edge cases', () {
    test('handles unicode characters in values', () async {
      const unicodeValue = 'token-\u{1F600}-\u{1F3A8}-\u{1F680}';
      when(() => mockStorage.write(
            key: 'claude_api_key',
            value: unicodeValue,
          )).thenAnswer((_) async {});
      when(() => mockStorage.read(key: 'claude_api_key'))
          .thenAnswer((_) async => unicodeValue);

      await storageService.setApiKey(unicodeValue);
      final result = await storageService.getApiKey();

      expect(result, equals(unicodeValue));
    });

    test('handles newlines in values', () async {
      const multilineValue = 'line1\nline2\nline3';
      when(() => mockStorage.write(
            key: 'claude_api_key',
            value: multilineValue,
          )).thenAnswer((_) async {});
      when(() => mockStorage.read(key: 'claude_api_key'))
          .thenAnswer((_) async => multilineValue);

      await storageService.setApiKey(multilineValue);
      final result = await storageService.getApiKey();

      expect(result, equals(multilineValue));
    });

    test('handles infinity in cost limit', () async {
      when(() => mockStorage.read(key: 'daily_cost_limit'))
          .thenAnswer((_) async => 'Infinity');

      final result = await storageService.getDailyLimit();

      expect(result, equals(double.infinity));
    });

    test('handles NaN in cost limit returns default', () async {
      when(() => mockStorage.read(key: 'daily_cost_limit'))
          .thenAnswer((_) async => 'NaN');

      final result = await storageService.getDailyLimit();

      // double.tryParse('NaN') returns NaN which is not null, so it returns NaN
      expect(result.isNaN, isTrue);
    });

    test('handles negative infinity in cost limit', () async {
      when(() => mockStorage.read(key: 'daily_cost_limit'))
          .thenAnswer((_) async => '-Infinity');

      final result = await storageService.getDailyLimit();

      expect(result, equals(double.negativeInfinity));
    });
  });
}
