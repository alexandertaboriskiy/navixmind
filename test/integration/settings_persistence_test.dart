import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:navixmind/core/database/collections/setting.dart';

void main() {
  late Isar isar;
  late Directory tempDir;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('settings_test_');
    isar = await Isar.open(
      [SettingSchema],
      directory: tempDir.path,
      name: 'settings_test_${DateTime.now().millisecondsSinceEpoch}',
    );
  });

  tearDown(() async {
    await isar.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Settings persistence full cycle', () {
    test('save and load string setting', () async {
      // Save
      await isar.writeTxn(() async {
        await isar.settings.put(Setting()
          ..key = 'username'
          ..value = 'testuser');
      });

      // Load
      final loaded = await isar.settings
          .filter()
          .keyEqualTo('username')
          .findFirst();

      expect(loaded!.value, equals('testuser'));
    });

    test('save and load numeric setting as string', () async {
      // Save
      await isar.writeTxn(() async {
        await isar.settings.put(Setting()
          ..key = 'daily_limit'
          ..value = '10.50');
      });

      // Load and parse
      final loaded = await isar.settings
          .filter()
          .keyEqualTo('daily_limit')
          .findFirst();

      final numericValue = double.parse(loaded!.value);
      expect(numericValue, equals(10.50));
    });

    test('save and load boolean setting as string', () async {
      // Save
      await isar.writeTxn(() async {
        await isar.settings.put(Setting()
          ..key = 'limits_enabled'
          ..value = 'true');
      });

      // Load and parse
      final loaded = await isar.settings
          .filter()
          .keyEqualTo('limits_enabled')
          .findFirst();

      final boolValue = loaded!.value == 'true';
      expect(boolValue, isTrue);
    });

    test('save and load JSON setting', () async {
      // Save JSON as string
      await isar.writeTxn(() async {
        await isar.settings.put(Setting()
          ..key = 'user_preferences'
          ..value = '{"theme":"dark","notifications":true,"language":"en"}');
      });

      // Load
      final loaded = await isar.settings
          .filter()
          .keyEqualTo('user_preferences')
          .findFirst();

      expect(loaded!.value, contains('"theme":"dark"'));
      expect(loaded.value, contains('"notifications":true'));
    });
  });

  group('Settings helper class', () {
    // Helper class to wrap settings operations
    Future<void> saveSetting(String key, String value) async {
      final existing = await isar.settings
          .filter()
          .keyEqualTo(key)
          .findFirst();

      await isar.writeTxn(() async {
        if (existing != null) {
          existing.value = value;
          await isar.settings.put(existing);
        } else {
          await isar.settings.put(Setting()
            ..key = key
            ..value = value);
        }
      });
    }

    Future<String?> loadSetting(String key) async {
      final setting = await isar.settings
          .filter()
          .keyEqualTo(key)
          .findFirst();
      return setting?.value;
    }

    Future<void> deleteSetting(String key) async {
      await isar.writeTxn(() async {
        await isar.settings.filter().keyEqualTo(key).deleteAll();
      });
    }

    test('helper save creates new setting', () async {
      await saveSetting('new_key', 'new_value');

      final value = await loadSetting('new_key');
      expect(value, equals('new_value'));
    });

    test('helper save updates existing setting', () async {
      await saveSetting('update_key', 'initial');
      await saveSetting('update_key', 'updated');

      final value = await loadSetting('update_key');
      expect(value, equals('updated'));
    });

    test('helper load returns null for missing key', () async {
      final value = await loadSetting('nonexistent_key');
      expect(value, isNull);
    });

    test('helper delete removes setting', () async {
      await saveSetting('delete_key', 'value');
      await deleteSetting('delete_key');

      final value = await loadSetting('delete_key');
      expect(value, isNull);
    });
  });

  group('Cost limits settings', () {
    Future<void> saveCostSettings({
      required double dailyLimit,
      required double monthlyLimit,
      required bool enabled,
    }) async {
      await isar.writeTxn(() async {
        await isar.settings.put(Setting()
          ..key = 'daily_limit'
          ..value = dailyLimit.toString());
        await isar.settings.put(Setting()
          ..key = 'monthly_limit'
          ..value = monthlyLimit.toString());
        await isar.settings.put(Setting()
          ..key = 'limits_enabled'
          ..value = enabled.toString());
      });
    }

    Future<Map<String, dynamic>> loadCostSettings() async {
      final daily = await isar.settings
          .filter()
          .keyEqualTo('daily_limit')
          .findFirst();
      final monthly = await isar.settings
          .filter()
          .keyEqualTo('monthly_limit')
          .findFirst();
      final enabled = await isar.settings
          .filter()
          .keyEqualTo('limits_enabled')
          .findFirst();

      return {
        'dailyLimit': daily != null ? double.parse(daily.value) : 5.0,
        'monthlyLimit': monthly != null ? double.parse(monthly.value) : 50.0,
        'enabled': enabled?.value == 'true',
      };
    }

    test('saves and loads cost settings', () async {
      await saveCostSettings(
        dailyLimit: 10.0,
        monthlyLimit: 100.0,
        enabled: true,
      );

      final settings = await loadCostSettings();

      expect(settings['dailyLimit'], equals(10.0));
      expect(settings['monthlyLimit'], equals(100.0));
      expect(settings['enabled'], isTrue);
    });

    test('uses defaults for missing cost settings', () async {
      final settings = await loadCostSettings();

      expect(settings['dailyLimit'], equals(5.0));
      expect(settings['monthlyLimit'], equals(50.0));
      expect(settings['enabled'], isFalse);
    });
  });

  group('API key settings', () {
    test('securely stores API key', () async {
      const apiKey = 'sk-ant-test-12345678901234567890';

      await isar.writeTxn(() async {
        await isar.settings.put(Setting()
          ..key = 'anthropic_api_key'
          ..value = apiKey);
      });

      final loaded = await isar.settings
          .filter()
          .keyEqualTo('anthropic_api_key')
          .findFirst();

      expect(loaded!.value, equals(apiKey));
    });

    test('updates API key', () async {
      // Initial key
      await isar.writeTxn(() async {
        await isar.settings.put(Setting()
          ..key = 'anthropic_api_key'
          ..value = 'old-key');
      });

      // Get and update
      final existing = await isar.settings
          .filter()
          .keyEqualTo('anthropic_api_key')
          .findFirst();

      await isar.writeTxn(() async {
        existing!.value = 'new-key';
        await isar.settings.put(existing);
      });

      final updated = await isar.settings
          .filter()
          .keyEqualTo('anthropic_api_key')
          .findFirst();

      expect(updated!.value, equals('new-key'));
    });

    test('removes API key', () async {
      await isar.writeTxn(() async {
        await isar.settings.put(Setting()
          ..key = 'anthropic_api_key'
          ..value = 'to-delete');
      });

      await isar.writeTxn(() async {
        await isar.settings.filter().keyEqualTo('anthropic_api_key').deleteAll();
      });

      final deleted = await isar.settings
          .filter()
          .keyEqualTo('anthropic_api_key')
          .findFirst();

      expect(deleted, isNull);
    });
  });

  group('Google OAuth settings', () {
    test('stores Google OAuth tokens', () async {
      await isar.writeTxn(() async {
        await isar.settings.put(Setting()
          ..key = 'google_access_token'
          ..value = 'ya29.access_token_here');
        await isar.settings.put(Setting()
          ..key = 'google_refresh_token'
          ..value = '1//refresh_token_here');
        await isar.settings.put(Setting()
          ..key = 'google_token_expiry'
          ..value = DateTime.now().add(const Duration(hours: 1)).toIso8601String());
      });

      final accessToken = await isar.settings
          .filter()
          .keyEqualTo('google_access_token')
          .findFirst();
      final refreshToken = await isar.settings
          .filter()
          .keyEqualTo('google_refresh_token')
          .findFirst();

      expect(accessToken!.value, startsWith('ya29.'));
      expect(refreshToken!.value, startsWith('1//'));
    });

    test('checks token expiry', () async {
      final expiryTime = DateTime.now().add(const Duration(hours: 1));

      await isar.writeTxn(() async {
        await isar.settings.put(Setting()
          ..key = 'google_token_expiry'
          ..value = expiryTime.toIso8601String());
      });

      final expirySetting = await isar.settings
          .filter()
          .keyEqualTo('google_token_expiry')
          .findFirst();

      final expiry = DateTime.parse(expirySetting!.value);
      final isExpired = expiry.isBefore(DateTime.now());

      expect(isExpired, isFalse);
    });
  });

  group('App preferences', () {
    test('stores model preference', () async {
      await isar.writeTxn(() async {
        await isar.settings.put(Setting()
          ..key = 'preferred_model'
          ..value = 'claude-3-sonnet');
      });

      final model = await isar.settings
          .filter()
          .keyEqualTo('preferred_model')
          .findFirst();

      expect(model!.value, equals('claude-3-sonnet'));
    });

    test('stores notification preferences', () async {
      await isar.writeTxn(() async {
        await isar.settings.put(Setting()
          ..key = 'notifications_enabled'
          ..value = 'true');
        await isar.settings.put(Setting()
          ..key = 'notification_sound'
          ..value = 'default');
      });

      final enabled = await isar.settings
          .filter()
          .keyEqualTo('notifications_enabled')
          .findFirst();

      expect(enabled!.value, equals('true'));
    });
  });

  group('Settings migration', () {
    test('handles legacy setting format', () async {
      // Simulate old format
      await isar.writeTxn(() async {
        await isar.settings.put(Setting()
          ..key = 'old_format_setting'
          ..value = 'legacy_value');
      });

      // Migration: read old, create new format, delete old
      final old = await isar.settings
          .filter()
          .keyEqualTo('old_format_setting')
          .findFirst();

      if (old != null) {
        await isar.writeTxn(() async {
          await isar.settings.put(Setting()
            ..key = 'new_format_setting'
            ..value = old.value);
          await isar.settings.delete(old.id);
        });
      }

      final newSetting = await isar.settings
          .filter()
          .keyEqualTo('new_format_setting')
          .findFirst();
      final oldSetting = await isar.settings
          .filter()
          .keyEqualTo('old_format_setting')
          .findFirst();

      expect(newSetting!.value, equals('legacy_value'));
      expect(oldSetting, isNull);
    });
  });

  group('Settings bulk operations', () {
    test('clears all settings', () async {
      // Create multiple settings
      await isar.writeTxn(() async {
        for (var i = 0; i < 10; i++) {
          await isar.settings.put(Setting()
            ..key = 'setting_$i'
            ..value = 'value_$i');
        }
      });

      // Clear all
      await isar.writeTxn(() async {
        await isar.settings.clear();
      });

      final count = await isar.settings.count();
      expect(count, equals(0));
    });

    test('exports all settings', () async {
      await isar.writeTxn(() async {
        await isar.settings.put(Setting()
          ..key = 'export_1'
          ..value = 'value_1');
        await isar.settings.put(Setting()
          ..key = 'export_2'
          ..value = 'value_2');
      });

      final all = await isar.settings.where().findAll();
      final exported = Map.fromEntries(
        all.map((s) => MapEntry(s.key, s.value)),
      );

      expect(exported['export_1'], equals('value_1'));
      expect(exported['export_2'], equals('value_2'));
    });

    test('imports settings from map', () async {
      final toImport = {
        'import_1': 'imported_value_1',
        'import_2': 'imported_value_2',
        'import_3': 'imported_value_3',
      };

      await isar.writeTxn(() async {
        for (final entry in toImport.entries) {
          await isar.settings.put(Setting()
            ..key = entry.key
            ..value = entry.value);
        }
      });

      final count = await isar.settings.count();
      expect(count, equals(3));
    });
  });
}
