// 這個檔案負責提供網路連線狀態資訊，供下載模組判斷 Wi-Fi 限制是否符合設定。
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 透過 Connectivity 套件查詢網路型態。
class NetworkStatus {
  NetworkStatus({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  /// 回傳目前是否處於 Wi-Fi 連線環境。
  Future<bool> isOnWifi() async {
    final result = await _connectivity.checkConnectivity();
    if (result is List<ConnectivityResult>) {
      return result.contains(ConnectivityResult.wifi);
    }
    return result == ConnectivityResult.wifi;
  }
}

/// 提供 NetworkStatus 物件的 Riverpod Provider，確保在應用內共用單一實例。
final networkStatusProvider = Provider<NetworkStatus>((ref) {
  return NetworkStatus();
}, name: 'networkStatusProvider');
