/// 這個檔案負責：
/// - App 進入點初始化（背景任務、背景播放初始化）
/// - 啟動 Riverpod 與主應用
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/background/download_work_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 如需 Android 系統通知與完整背景播放，之後可整合 just_audio_background 初始化於此。
  // 為避免缺少套件導致編譯失敗，先註解；待環境可安裝時再啟用：
  // await JustAudioBackground.init(
  //   androidNotificationChannelId: 'com.example.podcast_player.audio',
  //   androidNotificationChannelName: 'Podcast 播放',
  //   androidNotificationOngoing: true,
  // );
  if (Platform.isAndroid) {
    final workManager = DownloadWorkManager();
    await workManager.initialize();
    await workManager.scheduleMaintenance();
  }
  runApp(const ProviderScope(child: PodcastApp()));
}
