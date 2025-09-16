// 這個檔案封裝 WorkManager 註冊邏輯，用於定期觸發下載維護工作。
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';

import '../../features/download/application/download_controller.dart';

const _downloadMaintenanceTask = 'download_maintenance_task';
const _updatePodcastTask = 'download_auto_refresh_task';

@pragma('vm:entry-point')
void downloadBackgroundDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final container = ProviderContainer();
    final controller = container.read(downloadControllerProvider.notifier);
    switch (task) {
      case _downloadMaintenanceTask:
        await controller.performMaintenance();
        break;
      case _updatePodcastTask:
        final podcastId = inputData?['podcastId'] as String?;
        final episodes = inputData?['episodes'] as List<dynamic>?;
        if (podcastId != null && episodes != null) {
          // 此處僅預留：實際自動下載需額外資料，暫以維護作業替代。
          await controller.performMaintenance();
        } else {
          await controller.performMaintenance();
        }
        break;
      default:
        await controller.performMaintenance();
    }
    container.dispose();
    return true;
  });
}

class DownloadWorkManager {
  DownloadWorkManager();

  Future<void> initialize() async {
    if (!Platform.isAndroid) {
      return;
    }
    await Workmanager().initialize(
      downloadBackgroundDispatcher,
      isInDebugMode: false,
    );
  }

  Future<void> scheduleMaintenance({Duration frequency = const Duration(hours: 6)}) async {
    if (!Platform.isAndroid) {
      return;
    }
    await Workmanager().registerPeriodicTask(
      _downloadMaintenanceTask,
      _downloadMaintenanceTask,
      frequency: frequency,
      initialDelay: const Duration(minutes: 5),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }
}

final downloadWorkManagerProvider = Provider<DownloadWorkManager>((ref) {
  return DownloadWorkManager();
}, name: 'downloadWorkManagerProvider');
