import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/background/download_work_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isAndroid) {
    final workManager = DownloadWorkManager();
    await workManager.initialize();
    await workManager.scheduleMaintenance();
  }
  runApp(const ProviderScope(child: PodcastApp()));
}
