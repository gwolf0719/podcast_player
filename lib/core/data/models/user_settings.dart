// 這個檔案主要負責描述應用程式中的使用者下載與通知設定資料結構。
import 'package:meta/meta.dart';

/// 用來封裝使用者偏好的設定值，後續由儲存層與控制器共同操作。
@immutable
class UserSettings {
  /// 建構函式會指定 Wi-Fi 限制、要自動下載的集數以及容量上限（GB）。
  const UserSettings({
    required this.wifiOnly,
    required this.autoDownloadCount,
    required this.storageLimitGb,
    required this.retentionDays,
  });

  /// 是否僅允許在 Wi-Fi 環境下載。
  final bool wifiOnly;

  /// 每個訂閱要自動下載的最新集數數量。
  final int autoDownloadCount;

  /// 下載容量限制，單位 GB。
  final double storageLimitGb;

  /// 自動清理未保護下載檔案的天數，0 代表不自動清理。
  final int retentionDays;

  /// 透過 copyWith 產生新物件，以便更新單一欄位。
  UserSettings copyWith({
    bool? wifiOnly,
    int? autoDownloadCount,
    double? storageLimitGb,
    int? retentionDays,
  }) {
    return UserSettings(
      wifiOnly: wifiOnly ?? this.wifiOnly,
      autoDownloadCount: autoDownloadCount ?? this.autoDownloadCount,
      storageLimitGb: storageLimitGb ?? this.storageLimitGb,
      retentionDays: retentionDays ?? this.retentionDays,
    );
  }

  /// 將設定資料轉成 Map 供儲存層序列化存檔。
  Map<String, Object> toMap() {
    return {
      'wifiOnly': wifiOnly,
      'autoDownloadCount': autoDownloadCount,
      'storageLimitGb': storageLimitGb,
      'retentionDays': retentionDays,
    };
  }

  /// 由儲存層讀取的 Map 轉回設定實體，若缺資料則使用預設值。
  factory UserSettings.fromMap(Map<String, Object?> data) {
    return UserSettings(
      wifiOnly: (data['wifiOnly'] as bool?) ?? true,
      autoDownloadCount: (data['autoDownloadCount'] as int?) ?? 2,
      storageLimitGb: (data['storageLimitGb'] as double?) ?? 2.0,
      retentionDays: (data['retentionDays'] as int?) ?? 30,
    );
  }

  /// 提供預設設定，供首次啟動或儲存層尚未寫入時使用。
  static const UserSettings defaults = UserSettings(
    wifiOnly: true,
    autoDownloadCount: 2,
    storageLimitGb: 2.0,
    retentionDays: 30,
  );
}
