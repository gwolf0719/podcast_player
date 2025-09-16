import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:podcast_player/core/data/models/download_task.dart';
import 'package:podcast_player/core/data/models/podcast.dart';
import 'package:podcast_player/core/data/models/podcast.dart'
    as models
    show Episode;
import 'package:podcast_player/core/db/download_database.dart';
import 'package:podcast_player/core/download/audio_downloader.dart';
import 'package:podcast_player/features/download/application/download_controller.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.basePath);

  final String basePath;

  @override
  Future<String?> getApplicationDocumentsPath() async => basePath;
}

class _FakeDownloader implements AudioDownloader {
  bool shouldFailFirst = false;

  @override
  Future<void> download({
    required String url,
    required String savePath,
    required void Function(int received, int total) onReceiveProgress,
    required CancelToken cancelToken,
  }) async {
    final file = File(savePath);
    await file.create(recursive: true);

    if (shouldFailFirst) {
      shouldFailFirst = false;
      throw DioException(
        requestOptions: RequestOptions(path: url),
        type: DioExceptionType.badResponse,
      );
    }

    const total = 5;
    for (var i = 1; i <= total; i++) {
      if (cancelToken.isCancelled) {
        throw DioException(
          requestOptions: RequestOptions(path: url),
          type: DioExceptionType.cancel,
        );
      }
      onReceiveProgress(i, total);
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    await file.writeAsString('audio');
  }

  @override
  Future<bool> exists(String path) async => File(path).exists();
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory tempDir;
  late _FakeDownloader downloader;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('download_test');
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
    downloader = _FakeDownloader();
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<ProviderContainer> createContainer() async {
    final dbPath = p.join(tempDir.path, 'downloads.db');
    final container = ProviderContainer(
      overrides: [
        downloadDatabaseProvider.overrideWithValue(
          DownloadDatabase(overridePath: dbPath),
        ),
        audioDownloaderProvider.overrideWithValue(downloader),
      ],
    );
    return container;
  }

  test('下載完成後狀態為 completed 並有檔案', () async {
    final container = await createContainer();
    addTearDown(container.dispose);

    final notifier = container.read(downloadControllerProvider.notifier);
    final podcast = const Podcast(
      id: 'p1',
      title: 'Test Podcast',
      author: 'Author',
      feedUrl: 'https://example.com/feed',
      episodes: [],
    );
    const episode = models.Episode(
      id: 'episode1',
      title: 'Episode 1',
      audioUrl: 'https://example.com/audio.mp3',
    );

    await notifier.startDownload(podcast, episode);
    await Future<void>.delayed(const Duration(milliseconds: 150));

    final task = container
        .read(downloadControllerProvider)
        .firstWhere((task) => task.episodeId == episode.id);
    expect(task.status, DownloadStatus.completed);
    expect(task.filePath, isNotNull);
    expect(await File(task.filePath!).exists(), isTrue);
  });

  test('下載失敗後重試可成功', () async {
    downloader.shouldFailFirst = true;
    final container = await createContainer();
    addTearDown(container.dispose);

    final notifier = container.read(downloadControllerProvider.notifier);
    final podcast = const Podcast(
      id: 'p2',
      title: 'Test Podcast',
      author: 'Author',
      feedUrl: 'https://example.com/feed2',
      episodes: [],
    );
    const episode = models.Episode(
      id: 'episode2',
      title: 'Episode 2',
      audioUrl: 'https://example.com/audio2.mp3',
    );

    await notifier.startDownload(podcast, episode);
    await Future<void>.delayed(const Duration(milliseconds: 150));

    var task = container
        .read(downloadControllerProvider)
        .firstWhere((t) => t.episodeId == episode.id);
    expect(task.status, DownloadStatus.failed);

    await notifier.retry(task.id);
    await Future<void>.delayed(const Duration(milliseconds: 150));

    task = container
        .read(downloadControllerProvider)
        .firstWhere((t) => t.episodeId == episode.id);
    expect(task.status, DownloadStatus.completed);
  });
}
