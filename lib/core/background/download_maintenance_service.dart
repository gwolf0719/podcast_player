// 這個檔案負責週期執行下載佇列的保養作業（容量清理與保留期限控管）。
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/download/application/download_controller.dart';

/// 封裝下載維護邏輯，建立週期性排程觸發清理流程。
class DownloadMaintenanceService {
  DownloadMaintenanceService(this._ref) {
    _timer = Timer.periodic(_interval, (_) => _runMaintenance());
    _runMaintenance();
  }

  final Ref _ref;
  static const _interval = Duration(hours: 6);
  Timer? _timer;

  /// 立即執行一次維護作業，供外部觸發。
  Future<void> triggerNow() => _runMaintenance();

  Future<void> _runMaintenance() async {
    final controller = _ref.read(downloadControllerProvider.notifier);
    await controller.performMaintenance();
  }

  void dispose() {
    _timer?.cancel();
  }
}

/// 提供下載維護服務供應器，確保應用啟動時即開始排程。
final downloadMaintenanceServiceProvider = Provider<DownloadMaintenanceService>((ref) {
  final service = DownloadMaintenanceService(ref);
  ref.onDispose(service.dispose);
  return service;
}, name: 'downloadMaintenanceServiceProvider');
