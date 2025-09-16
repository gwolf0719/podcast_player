import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/design/app_theme.dart';
import 'core/navigation/app_router.dart';
import 'core/background/download_maintenance_service.dart';

class PodcastApp extends ConsumerWidget {
  const PodcastApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    ref.watch(downloadMaintenanceServiceProvider);

    // 強制使用「明亮模式」：統一 UI/UX 配色，避免暗色模式差異
    return MaterialApp.router(
      title: 'Podcast Player',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      themeMode: ThemeMode.light,
      routerConfig: router,
    );
  }
}
