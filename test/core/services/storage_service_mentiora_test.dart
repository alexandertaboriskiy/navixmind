import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// Mock class for FlutterSecureStorage
class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

/// Testable version of StorageService focused on Mentiora API key methods.
/// This mirrors the actual StorageService implementation but accepts an injected storage.
class TestableStorageService {
  final FlutterSecureStorage _storage;

  TestableStorageService(this._storage);

  // Key (same as actual StorageService)
  static const _keyMentioraApiKey = 'mentiora_api_key';

  /// Store Mentiora API key securely
  Future<void> setMentioraApiKey(String key) async {
    await _storage.write(key: _keyMentioraApiKey, value: key);
  }

  /// Get stored Mentiora API key
  Future<String?> getMentioraApiKey() async {
    return await _storage.read(key: _keyMentioraApiKey);
  }

  /// Check if Mentiora API key is stored
  Future<bool> hasMentioraApiKey() async {
    return await _storage.containsKey(key: _keyMentioraApiKey);
  }

  /// Delete Mentiora API key
  Future<void> deleteMentioraApiKey() async {
    await _storage.delete(key: _keyMentioraApiKey);
  }
}

void main() {
  late MockFlutterSecureStorage mockStorage;
  late TestableStorageService storageService;

  setUp(() {
    mockStorage = MockFlutterSecureStorage();
    storageService = TestableStorageService(mockStorage);
  });

  group('StorageService Mentiora API Key', () {
    group('setMentioraApiKey', () {
      test('stores Mentiora API key in secure storage', () async {
        when(() => mockStorage.write(
              key: 'mentiora_api_key',
              value: 'mnt-test-key-123',
            )).thenAnswer((_) async {});

        await storageService.setMentioraApiKey('mnt-test-key-123');

        verify(() => mockStorage.write(
              key: 'mentiora_api_key',
              value: 'mnt-test-key-123',
            )).called(1);
      });

      test('stores empty string API key', () async {
        when(() => mockStorage.write(
              key: 'mentiora_api_key',
              value: '',
            )).thenAnswer((_) async {});

        await storageService.setMentioraApiKey('');

        verify(() => mockStorage.write(
              key: 'mentiora_api_key',
              value: '',
            )).called(1);
      });

      test('overwrites existing API key', () async {
        when(() => mockStorage.write(
              key: 'mentiora_api_key',
              value: any(named: 'value'),
            )).thenAnswer((_) async {});

        await storageService.setMentioraApiKey('old-key');
        await storageService.setMentioraApiKey('new-key');

        verify(() => mockStorage.write(
              key: 'mentiora_api_key',
              value: 'old-key',
            )).called(1);
        verify(() => mockStorage.write(
              key: 'mentiora_api_key',
              value: 'new-key',
            )).called(1);
      });

      test('handles special characters in API key', () async {
        const specialKey = 'mnt-!@#\$%^&*()_+-=[]{}|;:,.<>?';
        when(() => mockStorage.write(
              key: 'mentiora_api_key',
              value: specialKey,
            )).thenAnswer((_) async {});

        await storageService.setMentioraApiKey(specialKey);

        verify(() => mockStorage.write(
              key: 'mentiora_api_key',
              value: specialKey,
            )).called(1);
      });

      test('handles very long API key', () async {
        final longKey = 'mnt-${'x' * 1000}';
        when(() => mockStorage.write(
              key: 'mentiora_api_key',
              value: longKey,
            )).thenAnswer((_) async {});

        await storageService.setMentioraApiKey(longKey);

        verify(() => mockStorage.write(
              key: 'mentiora_api_key',
              value: longKey,
            )).called(1);
      });

      test('handles whitespace-only API key', () async {
        const whitespaceKey = '   \t\n  ';
        when(() => mockStorage.write(
              key: 'mentiora_api_key',
              value: whitespaceKey,
            )).thenAnswer((_) async {});

        await storageService.setMentioraApiKey(whitespaceKey);

        verify(() => mockStorage.write(
              key: 'mentiora_api_key',
              value: whitespaceKey,
            )).called(1);
      });

      test('handles unicode characters in API key', () async {
        const unicodeKey = 'mnt-\u{1F600}-\u{1F3A8}-\u{1F680}';
        when(() => mockStorage.write(
              key: 'mentiora_api_key',
              value: unicodeKey,
            )).thenAnswer((_) async {});

        await storageService.setMentioraApiKey(unicodeKey);

        verify(() => mockStorage.write(
              key: 'mentiora_api_key',
              value: unicodeKey,
            )).called(1);
      });

      test('handles newlines in API key', () async {
        const multilineKey = 'line1\nline2\nline3';
        when(() => mockStorage.write(
              key: 'mentiora_api_key',
              value: multilineKey,
            )).thenAnswer((_) async {});

        await storageService.setMentioraApiKey(multilineKey);

        verify(() => mockStorage.write(
              key: 'mentiora_api_key',
              value: multilineKey,
            )).called(1);
      });
    });

    group('getMentioraApiKey', () {
      test('returns stored Mentiora API key', () async {
        when(() => mockStorage.read(key: 'mentiora_api_key'))
            .thenAnswer((_) async => 'mnt-test-key-123');

        final result = await storageService.getMentioraApiKey();

        expect(result, equals('mnt-test-key-123'));
        verify(() => mockStorage.read(key: 'mentiora_api_key')).called(1);
      });

      test('returns null when no Mentiora API key is stored', () async {
        when(() => mockStorage.read(key: 'mentiora_api_key'))
            .thenAnswer((_) async => null);

        final result = await storageService.getMentioraApiKey();

        expect(result, isNull);
      });

      test('returns empty string when empty string was stored', () async {
        when(() => mockStorage.read(key: 'mentiora_api_key'))
            .thenAnswer((_) async => '');

        final result = await storageService.getMentioraApiKey();

        expect(result, equals(''));
      });

      test('returns whitespace string when whitespace was stored', () async {
        when(() => mockStorage.read(key: 'mentiora_api_key'))
            .thenAnswer((_) async => '   ');

        final result = await storageService.getMentioraApiKey();

        expect(result, equals('   '));
      });

      test('returns key with special characters', () async {
        const specialKey = 'mnt-key-with-!@#\$%^&*()';
        when(() => mockStorage.read(key: 'mentiora_api_key'))
            .thenAnswer((_) async => specialKey);

        final result = await storageService.getMentioraApiKey();

        expect(result, equals(specialKey));
      });

      test('returns very long key', () async {
        final longKey = 'mnt-${'y' * 2000}';
        when(() => mockStorage.read(key: 'mentiora_api_key'))
            .thenAnswer((_) async => longKey);

        final result = await storageService.getMentioraApiKey();

        expect(result, equals(longKey));
      });
    });

    group('hasMentioraApiKey', () {
      test('returns true when Mentiora API key exists', () async {
        when(() => mockStorage.containsKey(key: 'mentiora_api_key'))
            .thenAnswer((_) async => true);

        final result = await storageService.hasMentioraApiKey();

        expect(result, isTrue);
        verify(() => mockStorage.containsKey(key: 'mentiora_api_key'))
            .called(1);
      });

      test('returns false when Mentiora API key does not exist', () async {
        when(() => mockStorage.containsKey(key: 'mentiora_api_key'))
            .thenAnswer((_) async => false);

        final result = await storageService.hasMentioraApiKey();

        expect(result, isFalse);
      });

      test('returns true even when stored value is empty string', () async {
        // containsKey returns true even if the stored value is an empty string
        when(() => mockStorage.containsKey(key: 'mentiora_api_key'))
            .thenAnswer((_) async => true);

        final result = await storageService.hasMentioraApiKey();

        expect(result, isTrue);
      });

      test('can be called multiple times', () async {
        when(() => mockStorage.containsKey(key: 'mentiora_api_key'))
            .thenAnswer((_) async => true);

        await storageService.hasMentioraApiKey();
        await storageService.hasMentioraApiKey();
        await storageService.hasMentioraApiKey();

        verify(() => mockStorage.containsKey(key: 'mentiora_api_key'))
            .called(3);
      });
    });

    group('deleteMentioraApiKey', () {
      test('deletes Mentiora API key from storage', () async {
        when(() => mockStorage.delete(key: 'mentiora_api_key'))
            .thenAnswer((_) async {});

        await storageService.deleteMentioraApiKey();

        verify(() => mockStorage.delete(key: 'mentiora_api_key')).called(1);
      });

      test('succeeds even when Mentiora API key does not exist', () async {
        when(() => mockStorage.delete(key: 'mentiora_api_key'))
            .thenAnswer((_) async {});

        await expectLater(storageService.deleteMentioraApiKey(), completes);
      });

      test('can be called multiple times', () async {
        when(() => mockStorage.delete(key: 'mentiora_api_key'))
            .thenAnswer((_) async {});

        await storageService.deleteMentioraApiKey();
        await storageService.deleteMentioraApiKey();
        await storageService.deleteMentioraApiKey();

        verify(() => mockStorage.delete(key: 'mentiora_api_key')).called(3);
      });
    });
  });

  group('StorageService Mentiora API Key Integration scenarios', () {
    test('set and get Mentiora API key workflow', () async {
      const apiKey = 'mnt-api-key-12345';

      when(() => mockStorage.write(
            key: 'mentiora_api_key',
            value: apiKey,
          )).thenAnswer((_) async {});
      when(() => mockStorage.read(key: 'mentiora_api_key'))
          .thenAnswer((_) async => apiKey);
      when(() => mockStorage.containsKey(key: 'mentiora_api_key'))
          .thenAnswer((_) async => true);

      // Set the key
      await storageService.setMentioraApiKey(apiKey);

      // Verify it exists
      final hasKey = await storageService.hasMentioraApiKey();
      expect(hasKey, isTrue);

      // Get the key
      final retrievedKey = await storageService.getMentioraApiKey();
      expect(retrievedKey, equals(apiKey));
    });

    test('delete and verify Mentiora API key workflow', () async {
      when(() => mockStorage.delete(key: 'mentiora_api_key'))
          .thenAnswer((_) async {});
      when(() => mockStorage.containsKey(key: 'mentiora_api_key'))
          .thenAnswer((_) async => false);
      when(() => mockStorage.read(key: 'mentiora_api_key'))
          .thenAnswer((_) async => null);

      // Delete the key
      await storageService.deleteMentioraApiKey();

      // Verify it no longer exists
      final hasKey = await storageService.hasMentioraApiKey();
      expect(hasKey, isFalse);

      // Get returns null
      final retrievedKey = await storageService.getMentioraApiKey();
      expect(retrievedKey, isNull);
    });

    test('overwrite Mentiora API key with new value', () async {
      const oldKey = 'mnt-old-key-111';
      const newKey = 'mnt-new-key-222';

      when(() => mockStorage.write(
            key: 'mentiora_api_key',
            value: any(named: 'value'),
          )).thenAnswer((_) async {});

      // Set initial key
      await storageService.setMentioraApiKey(oldKey);

      // Update mock to return new key after overwrite
      when(() => mockStorage.read(key: 'mentiora_api_key'))
          .thenAnswer((_) async => newKey);

      // Overwrite with new key
      await storageService.setMentioraApiKey(newKey);

      // Verify the new key is returned
      final retrievedKey = await storageService.getMentioraApiKey();
      expect(retrievedKey, equals(newKey));

      // Verify write was called for both old and new keys
      verify(() => mockStorage.write(
            key: 'mentiora_api_key',
            value: oldKey,
          )).called(1);
      verify(() => mockStorage.write(
            key: 'mentiora_api_key',
            value: newKey,
          )).called(1);
    });

    test('set, delete, then verify key is gone', () async {
      const apiKey = 'mnt-temporary-key';

      when(() => mockStorage.write(
            key: 'mentiora_api_key',
            value: apiKey,
          )).thenAnswer((_) async {});
      when(() => mockStorage.delete(key: 'mentiora_api_key'))
          .thenAnswer((_) async {});

      // Set key
      await storageService.setMentioraApiKey(apiKey);

      // Delete key
      await storageService.deleteMentioraApiKey();

      // Update mocks for post-delete state
      when(() => mockStorage.containsKey(key: 'mentiora_api_key'))
          .thenAnswer((_) async => false);
      when(() => mockStorage.read(key: 'mentiora_api_key'))
          .thenAnswer((_) async => null);

      // Verify key is gone
      final hasKey = await storageService.hasMentioraApiKey();
      expect(hasKey, isFalse);

      final retrievedKey = await storageService.getMentioraApiKey();
      expect(retrievedKey, isNull);
    });

    test('set empty string, has returns true, get returns empty', () async {
      when(() => mockStorage.write(
            key: 'mentiora_api_key',
            value: '',
          )).thenAnswer((_) async {});
      when(() => mockStorage.containsKey(key: 'mentiora_api_key'))
          .thenAnswer((_) async => true);
      when(() => mockStorage.read(key: 'mentiora_api_key'))
          .thenAnswer((_) async => '');

      // Set empty string
      await storageService.setMentioraApiKey('');

      // Has returns true (key exists, even if value is empty)
      final hasKey = await storageService.hasMentioraApiKey();
      expect(hasKey, isTrue);

      // Get returns empty string
      final retrievedKey = await storageService.getMentioraApiKey();
      expect(retrievedKey, equals(''));
      expect(retrievedKey, isNotNull);
    });

    test('delete then set new key workflow', () async {
      const newKey = 'mnt-fresh-key-999';

      when(() => mockStorage.delete(key: 'mentiora_api_key'))
          .thenAnswer((_) async {});
      when(() => mockStorage.write(
            key: 'mentiora_api_key',
            value: newKey,
          )).thenAnswer((_) async {});
      when(() => mockStorage.read(key: 'mentiora_api_key'))
          .thenAnswer((_) async => newKey);
      when(() => mockStorage.containsKey(key: 'mentiora_api_key'))
          .thenAnswer((_) async => true);

      // Delete any existing key
      await storageService.deleteMentioraApiKey();

      // Set a fresh key
      await storageService.setMentioraApiKey(newKey);

      // Verify it exists
      final hasKey = await storageService.hasMentioraApiKey();
      expect(hasKey, isTrue);

      // Get the fresh key
      final retrievedKey = await storageService.getMentioraApiKey();
      expect(retrievedKey, equals(newKey));
    });
  });

  group('StorageService Mentiora API Key Error handling', () {
    test('handles storage write exception', () async {
      when(() => mockStorage.write(
            key: 'mentiora_api_key',
            value: any(named: 'value'),
          )).thenThrow(Exception('Storage write failed'));

      expect(
        () => storageService.setMentioraApiKey('test-key'),
        throwsA(isA<Exception>()),
      );
    });

    test('handles storage read exception', () async {
      when(() => mockStorage.read(key: 'mentiora_api_key'))
          .thenThrow(Exception('Storage read failed'));

      expect(
        () => storageService.getMentioraApiKey(),
        throwsA(isA<Exception>()),
      );
    });

    test('handles storage delete exception', () async {
      when(() => mockStorage.delete(key: 'mentiora_api_key'))
          .thenThrow(Exception('Storage delete failed'));

      expect(
        () => storageService.deleteMentioraApiKey(),
        throwsA(isA<Exception>()),
      );
    });

    test('handles storage containsKey exception', () async {
      when(() => mockStorage.containsKey(key: 'mentiora_api_key'))
          .thenThrow(Exception('Storage containsKey failed'));

      expect(
        () => storageService.hasMentioraApiKey(),
        throwsA(isA<Exception>()),
      );
    });

    test('write exception does not corrupt subsequent reads', () async {
      // First write throws
      when(() => mockStorage.write(
            key: 'mentiora_api_key',
            value: 'bad-key',
          )).thenThrow(Exception('Storage write failed'));

      expect(
        () => storageService.setMentioraApiKey('bad-key'),
        throwsA(isA<Exception>()),
      );

      // Subsequent read should still work (returns null since nothing was stored)
      when(() => mockStorage.read(key: 'mentiora_api_key'))
          .thenAnswer((_) async => null);

      final result = await storageService.getMentioraApiKey();
      expect(result, isNull);
    });
  });

  group('StorageService Mentiora API Key Concurrent operations', () {
    test('handles multiple concurrent reads of Mentiora API key', () async {
      when(() => mockStorage.read(key: 'mentiora_api_key'))
          .thenAnswer((_) async => 'mnt-concurrent-key');

      // Execute multiple reads concurrently
      final results = await Future.wait([
        storageService.getMentioraApiKey(),
        storageService.getMentioraApiKey(),
        storageService.getMentioraApiKey(),
      ]);

      expect(results[0], equals('mnt-concurrent-key'));
      expect(results[1], equals('mnt-concurrent-key'));
      expect(results[2], equals('mnt-concurrent-key'));
      verify(() => mockStorage.read(key: 'mentiora_api_key')).called(3);
    });

    test('handles concurrent has and get operations', () async {
      when(() => mockStorage.containsKey(key: 'mentiora_api_key'))
          .thenAnswer((_) async => true);
      when(() => mockStorage.read(key: 'mentiora_api_key'))
          .thenAnswer((_) async => 'mnt-concurrent-key');

      final results = await Future.wait([
        storageService.hasMentioraApiKey(),
        storageService.getMentioraApiKey(),
        storageService.hasMentioraApiKey(),
      ]);

      expect(results[0], isTrue);
      expect(results[1], equals('mnt-concurrent-key'));
      expect(results[2], isTrue);
    });

    test('handles concurrent set and delete operations', () async {
      when(() => mockStorage.write(
            key: 'mentiora_api_key',
            value: any(named: 'value'),
          )).thenAnswer((_) async {});
      when(() => mockStorage.delete(key: 'mentiora_api_key'))
          .thenAnswer((_) async {});

      // Execute write and delete concurrently
      await Future.wait([
        storageService.setMentioraApiKey('mnt-key-1'),
        storageService.deleteMentioraApiKey(),
        storageService.setMentioraApiKey('mnt-key-2'),
      ]);

      verify(() => mockStorage.write(
            key: 'mentiora_api_key',
            value: 'mnt-key-1',
          )).called(1);
      verify(() => mockStorage.write(
            key: 'mentiora_api_key',
            value: 'mnt-key-2',
          )).called(1);
      verify(() => mockStorage.delete(key: 'mentiora_api_key')).called(1);
    });
  });

  group('StorageService Mentiora API Key Edge cases', () {
    test('handles key that looks like a different storage key', () async {
      const confusingKey = 'claude_api_key';
      when(() => mockStorage.write(
            key: 'mentiora_api_key',
            value: confusingKey,
          )).thenAnswer((_) async {});
      when(() => mockStorage.read(key: 'mentiora_api_key'))
          .thenAnswer((_) async => confusingKey);

      await storageService.setMentioraApiKey(confusingKey);
      final result = await storageService.getMentioraApiKey();

      // The value is stored under 'mentiora_api_key', not confused with the Claude key
      expect(result, equals(confusingKey));
      verify(() => mockStorage.write(
            key: 'mentiora_api_key',
            value: confusingKey,
          )).called(1);
    });

    test('handles null bytes in API key', () async {
      const nullByteKey = 'mnt-key\x00with-null';
      when(() => mockStorage.write(
            key: 'mentiora_api_key',
            value: nullByteKey,
          )).thenAnswer((_) async {});
      when(() => mockStorage.read(key: 'mentiora_api_key'))
          .thenAnswer((_) async => nullByteKey);

      await storageService.setMentioraApiKey(nullByteKey);
      final result = await storageService.getMentioraApiKey();

      expect(result, equals(nullByteKey));
    });

    test('handles key with only whitespace and tabs', () async {
      const whitespaceKey = '\t \n \r\n \t';
      when(() => mockStorage.write(
            key: 'mentiora_api_key',
            value: whitespaceKey,
          )).thenAnswer((_) async {});
      when(() => mockStorage.read(key: 'mentiora_api_key'))
          .thenAnswer((_) async => whitespaceKey);

      await storageService.setMentioraApiKey(whitespaceKey);
      final result = await storageService.getMentioraApiKey();

      expect(result, equals(whitespaceKey));
    });

    test('handles extremely long API key (10000 chars)', () async {
      final extremelyLongKey = 'mnt-${'a' * 10000}';
      when(() => mockStorage.write(
            key: 'mentiora_api_key',
            value: extremelyLongKey,
          )).thenAnswer((_) async {});
      when(() => mockStorage.read(key: 'mentiora_api_key'))
          .thenAnswer((_) async => extremelyLongKey);

      await storageService.setMentioraApiKey(extremelyLongKey);
      final result = await storageService.getMentioraApiKey();

      expect(result, equals(extremelyLongKey));
      expect(result!.length, equals(10004)); // 'mnt-' + 10000 'a's
    });

    test('storage key constant is mentiora_api_key', () async {
      // Verify the actual storage key used is 'mentiora_api_key'
      when(() => mockStorage.write(
            key: 'mentiora_api_key',
            value: 'test',
          )).thenAnswer((_) async {});

      await storageService.setMentioraApiKey('test');

      // This verifies the exact key string used in storage
      verify(() => mockStorage.write(
            key: 'mentiora_api_key',
            value: 'test',
          )).called(1);

      // Ensure it was NOT written under any other key
      verifyNever(() => mockStorage.write(
            key: 'claude_api_key',
            value: any(named: 'value'),
          ));
    });

    test('set and immediately get returns the correct value', () async {
      const key = 'mnt-instant-key';
      when(() => mockStorage.write(
            key: 'mentiora_api_key',
            value: key,
          )).thenAnswer((_) async {});
      when(() => mockStorage.read(key: 'mentiora_api_key'))
          .thenAnswer((_) async => key);

      await storageService.setMentioraApiKey(key);
      final result = await storageService.getMentioraApiKey();

      expect(result, equals(key));
    });

    test('multiple overwrites end with final value', () async {
      when(() => mockStorage.write(
            key: 'mentiora_api_key',
            value: any(named: 'value'),
          )).thenAnswer((_) async {});

      // Write 5 different values in sequence
      await storageService.setMentioraApiKey('key-1');
      await storageService.setMentioraApiKey('key-2');
      await storageService.setMentioraApiKey('key-3');
      await storageService.setMentioraApiKey('key-4');
      await storageService.setMentioraApiKey('key-5');

      // Mock returns the final value
      when(() => mockStorage.read(key: 'mentiora_api_key'))
          .thenAnswer((_) async => 'key-5');

      final result = await storageService.getMentioraApiKey();
      expect(result, equals('key-5'));

      // Verify all 5 writes occurred
      verify(() => mockStorage.write(
            key: 'mentiora_api_key',
            value: any(named: 'value'),
          )).called(5);
    });

    test('delete non-existent key then has returns false', () async {
      when(() => mockStorage.delete(key: 'mentiora_api_key'))
          .thenAnswer((_) async {});
      when(() => mockStorage.containsKey(key: 'mentiora_api_key'))
          .thenAnswer((_) async => false);

      // Delete (nothing to delete)
      await storageService.deleteMentioraApiKey();

      // Has should return false
      final hasKey = await storageService.hasMentioraApiKey();
      expect(hasKey, isFalse);
    });
  });
}
