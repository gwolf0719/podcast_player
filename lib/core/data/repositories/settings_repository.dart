// 這個檔案負責透過 SharedPreferences 儲存與讀取使用者設定，模擬 DataStore 的持久化層。
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_settings.dart';

/// 提供外部註冊與銷毀的 SettingsRepository，維持單一實例。
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final repository = SettingsRepository();
  ref.onDispose(repository.dispose);
  return repository;
}, name: 'settingsRepositoryProvider');

/// 使用 SharedPreferences 存取設定值，並提供快取與監聽功能。
class SettingsRepository {
  SettingsRepository({Future<SharedPreferences>? preferences})
      : _preferencesFuture = preferences ?? SharedPreferences.getInstance();

  final Future<SharedPreferences> _preferencesFuture;
  final _controller = StreamController<UserSettings>.broadcast();
  UserSettings _cache = UserSettings.defaults;

  /// 讀取儲存的設定，若尚未寫入則回傳預設值，並更新快取。
  Future<UserSettings> load() async {
    final prefs = await _preferencesFuture;
    final wifiOnly = prefs.getBool(_wifiOnlyKey);
    final autoCount = prefs.getInt(_autoDownloadKey);
    final storage = prefs.getDouble(_storageLimitKey);
    final retention = prefs.getInt(_retentionDaysKey);
    _cache = UserSettings(
      wifiOnly: wifiOnly ?? UserSettings.defaults.wifiOnly,
      autoDownloadCount: autoCount ?? UserSettings.defaults.autoDownloadCount,
      storageLimitGb: storage ?? UserSettings.defaults.storageLimitGb,
      retentionDays: retention ?? UserSettings.defaults.retentionDays,
    );
    return _cache;
  }

  /// 將新的設定寫入 SharedPreferences，並同步廣播給訂閱者。
  Future<void> save(UserSettings settings) async {
    final prefs = await _preferencesFuture;
    await prefs.setBool(_wifiOnlyKey, settings.wifiOnly);
    await prefs.setInt(_autoDownloadKey, settings.autoDownloadCount);
    await prefs.setDouble(_storageLimitKey, settings.storageLimitGb);
    await prefs.setInt(_retentionDaysKey, settings.retentionDays);
    _cache = settings;
    _controller.add(settings);
  }

  /// 取得最後一次快取的設定資料，提供同步讀取需求。
  UserSettings get current => _cache;

  /// 將設定更新通知暴露為 stream，供其他模組觀察設定變動。
  Stream<UserSettings> get stream async* {
    yield _cache;
    yield* _controller.stream;
  }

  /// 清除資源避免記憶體洩漏。
  void dispose() {
    _controller.close();
  }

  static const _wifiOnlyKey = 'settings_wifi_only';
  static const _autoDownloadKey = 'settings_auto_download_count';
  static const _storageLimitKey = 'settings_storage_limit_gb';
  static const _retentionDaysKey = 'settings_retention_days';
}
