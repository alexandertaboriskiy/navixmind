import 'dart:convert';

import 'package:isar/isar.dart';

part 'setting.g.dart';

@collection
class Setting {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String key;

  /// JSON-encoded value for complex settings
  late String value;

  Setting();

  factory Setting.create({
    required String key,
    required dynamic value,
  }) {
    return Setting()
      ..key = key
      ..value = jsonEncode(value);
  }

  /// Get typed value
  T getValue<T>() {
    return jsonDecode(value) as T;
  }

  /// Common setting keys
  static const keyDailySpendingLimit = 'daily_spending_limit';
  static const keyWarningThreshold = 'warning_threshold';
  static const keyNotificationsEnabled = 'notifications_enabled';
  static const keyThemeMode = 'theme_mode';
  static const keyTextScaleFactor = 'text_scale_factor';
  static const keyReduceMotion = 'reduce_motion';
  static const keyAnalyticsEnabled = 'analytics_enabled';
  static const keyOnboardingCompleted = 'onboarding_completed';
}

/// Repository for settings
class SettingsRepository {
  final Isar _isar;

  SettingsRepository(this._isar);

  Future<T?> get<T>(String key) async {
    final setting = await _isar.settings.where().keyEqualTo(key).findFirst();
    if (setting == null) return null;
    return setting.getValue<T>();
  }

  Future<void> set(String key, dynamic value) async {
    await _isar.writeTxn(() async {
      await _isar.settings.put(Setting.create(key: key, value: value));
    });
  }

  Future<void> delete(String key) async {
    await _isar.writeTxn(() async {
      await _isar.settings.where().keyEqualTo(key).deleteAll();
    });
  }

  // Convenience getters with defaults
  Future<double> getDailySpendingLimit() async {
    return await get<double>(Setting.keyDailySpendingLimit) ?? 0.50;
  }

  Future<bool> getNotificationsEnabled() async {
    return await get<bool>(Setting.keyNotificationsEnabled) ?? true;
  }

  Future<bool> getOnboardingCompleted() async {
    return await get<bool>(Setting.keyOnboardingCompleted) ?? false;
  }
}
