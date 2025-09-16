import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('下載與同步', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: const [
              ListTile(
                leading: Icon(Icons.wifi),
                title: Text('僅在 Wi-Fi 環境自動下載'),
                subtitle: Text('預設開啟，可於後續實作中調整為行動網路'),
              ),
              Divider(height: 1),
              ListTile(
                leading: Icon(Icons.library_music_outlined),
                title: Text('自動下載最新 2 集'),
                subtitle: Text('設定值 1-3 集將在設定儲存層完成後開放調整'),
              ),
              Divider(height: 1),
              ListTile(
                leading: Icon(Icons.sd_card_outlined),
                title: Text('下載容量上限 2GB'),
                subtitle: Text('後續會與清理策略整合並提供 DataStore 儲存'),
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
  }
}
