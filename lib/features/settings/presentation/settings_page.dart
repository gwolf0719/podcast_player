import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/settings_controller.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsControllerProvider);

    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 12),
              Text('載入設定失敗：$error', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.invalidate(settingsControllerProvider),
                child: const Text('重新嘗試'),
              ),
            ],
          ),
        ),
      ),
      data: (settings) {
        final controller = ref.read(settingsControllerProvider.notifier);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('下載與同步', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    value: settings.wifiOnly,
                    onChanged: controller.toggleWifiOnly,
                    secondary: const Icon(Icons.wifi),
                    title: const Text('僅在 Wi-Fi 環境自動下載'),
                    subtitle: const Text('避免使用行動網路消耗流量'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.library_music_outlined),
                    title: const Text('自動下載集數'),
                    subtitle: Text('目前設定：最新 ${settings.autoDownloadCount} 集'),
                    trailing: DropdownButton<int>(
                      value: settings.autoDownloadCount,
                      items: const [1, 2, 3]
                          .map((value) => DropdownMenuItem<int>(
                                value: value,
                                child: Text('$value 集'),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          controller.updateAutoDownloadCount(value);
                        }
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.sd_card_outlined),
                    title: const Text('下載容量上限'),
                    subtitle: Text('${settings.storageLimitGb.toStringAsFixed(1)} GB'),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Slider(
                      value: settings.storageLimitGb,
                      min: 1,
                      max: 5,
                      divisions: 8,
                      label: '${settings.storageLimitGb.toStringAsFixed(1)} GB',
                      onChanged: (value) => controller.updateStorageLimit(value),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.calendar_today_outlined),
                    title: const Text('自動清理未保護下載'),
                    subtitle: Text(
                      settings.retentionDays == 0
                          ? '不自動清理'
                          : '保留 ${settings.retentionDays} 天後自動清除',
                    ),
                    trailing: DropdownButton<int>(
                      value: settings.retentionDays,
                      items: const [0, 7, 14, 30, 60]
                          .map(
                            (value) => DropdownMenuItem<int>(
                              value: value,
                              child: Text(value == 0 ? '不清理' : '$value 天'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          controller.updateRetentionDays(value);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('通知', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: const [
                  ListTile(
                    leading: Icon(Icons.notifications_active_outlined),
                    title: Text('新集數通知'),
                    subtitle: Text('會在背景更新與通知模組實作後啟用'),
                  ),
                  Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.calendar_month_outlined),
                    title: Text('每日摘要時間'),
                    subtitle: Text('預設 09:00，後續提供時間選擇器'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('資料管理', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: const [
                  ListTile(
                    leading: Icon(Icons.file_upload_outlined),
                    title: Text('匯出 OPML'),
                    subtitle: Text('將在訂閱模組完成後提供匯出功能'),
                  ),
                  Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.file_download_outlined),
                    title: Text('匯入 OPML'),
                    subtitle: Text('提供檔案選擇與重複去除流程'),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
