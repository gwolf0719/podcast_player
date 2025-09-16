// 這個檔案負責封裝設定頁面使用的狀態控制邏輯，串接儲存層並暴露更新方法。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/models/user_settings.dart';
import '../../../core/data/repositories/settings_repository.dart';

/// 提供設定頁使用的 AsyncNotifier，確保資料讀取與更新流程一致。
final settingsControllerProvider =
    AutoDisposeAsyncNotifierProvider<SettingsController, UserSettings>(
  SettingsController.new,
  name: 'settingsControllerProvider',
);

/// 控制設定頁狀態的類別，負責讀取與更新使用者偏好。
class SettingsController extends AutoDisposeAsyncNotifier<UserSettings> {
  @override
  Future<UserSettings> build() async {
    final repository = ref.read(settingsRepositoryProvider);
    final settings = await repository.load();
    _listenRepositoryUpdates();
    return settings;
  }

  /// 監聽儲存層的更新事件，確保狀態保持同步。
  void _listenRepositoryUpdates() {
    final repository = ref.read(settingsRepositoryProvider);
    final sub = repository.stream.listen((settings) {
      state = AsyncValue.data(settings);
    });
    ref.onDispose(sub.cancel);
  }

  /// 切換 Wi-Fi 限制，並同步寫回儲存層。
  Future<void> toggleWifiOnly(bool value) async {
    final currentSettings = state.requireValue;
    final updated = currentSettings.copyWith(wifiOnly: value);
    await _persist(updated);
  }

  /// 調整自動下載集數限制。
  Future<void> updateAutoDownloadCount(int count) async {
    final currentSettings = state.requireValue;
    final updated = currentSettings.copyWith(autoDownloadCount: count);
    await _persist(updated);
  }

  /// 更新容量上限（GB）。
  Future<void> updateStorageLimit(double limitGb) async {
    final currentSettings = state.requireValue;
    final updated = currentSettings.copyWith(storageLimitGb: limitGb);
    await _persist(updated);
  }

  /// 設定下載保留天數，0 代表不自動清理。
  Future<void> updateRetentionDays(int days) async {
    final currentSettings = state.requireValue;
    final updated = currentSettings.copyWith(retentionDays: days);
    await _persist(updated);
  }

  Future<void> _persist(UserSettings settings) async {
    final repository = ref.read(settingsRepositoryProvider);
    state = AsyncValue.data(settings);
    try {
      await repository.save(settings);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}
