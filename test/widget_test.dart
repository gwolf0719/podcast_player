// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:podcast_player/app.dart';
import 'package:podcast_player/core/audio/audio_engine.dart';
import 'package:podcast_player/core/data/models/podcast.dart';
import 'package:podcast_player/core/data/models/search_results.dart';
import 'package:podcast_player/core/data/preview/fake_podcasts.dart';
import 'package:podcast_player/core/db/download_database.dart';
import 'package:podcast_player/core/download/audio_downloader.dart';
import 'package:podcast_player/core/network/apple_podcasts_search_client.dart';
import 'package:podcast_player/features/discover/presentation/discover_controller.dart';

class _FakeDiscoverController extends DiscoverController {
  _FakeDiscoverController(this._podcasts);

  final List<Podcast> _podcasts;

  @override
  Future<List<Podcast>> build() async => _podcasts;
}

class _FakeSearchClient extends ApplePodcastsSearchClient {
  _FakeSearchClient() : super(httpClient: http.Client());

  @override
  Future<SearchResults> search(String term) async {
    if (term.trim().isEmpty) {
      return SearchResults.empty;
    }
    return SearchResults(
      podcasts: samplePodcasts,
      episodes: samplePodcasts.first.episodes,
    );
  }
}

class _StubAudioEngine implements AudioEngine {
  @override
  Stream<Duration> get positionStream => const Stream.empty();

  @override
  Stream<Duration?> get durationStream => const Stream.empty();

  @override
  Stream<EngineStatus> get statusStream => const Stream.empty();

  @override
  Future<void> dispose() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> setUrl(String url) async {}

  @override
  Future<void> stop() async {}
}

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.basePath);

  final String basePath;

  @override
  Future<String?> getApplicationDocumentsPath() async => basePath;
}

class _StubAudioDownloader implements AudioDownloader {
  @override
  Future<void> download({
    required String url,
    required String savePath,
    required void Function(int received, int total) onReceiveProgress,
    required CancelToken cancelToken,
  }) async {
    final file = File(savePath);
    await file.create(recursive: true);
    onReceiveProgress(1, 1);
    await file.writeAsString('audio');
  }

  @override
  Future<bool> exists(String path) async => File(path).exists();
}

late Directory _widgetTestDir;

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    _widgetTestDir = await Directory.systemTemp.createTemp('widget_test');
    PathProviderPlatform.instance = _FakePathProvider(_widgetTestDir.path);
  });

  tearDownAll(() async {
    if (await _widgetTestDir.exists()) {
      await _widgetTestDir.delete(recursive: true);
    }
  });

  testWidgets('App shell renders導覽列與探索標題', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          discoverControllerProvider.overrideWith(
            () => _FakeDiscoverController(samplePodcasts),
          ),
          applePodcastsSearchClientProvider.overrideWithValue(
            _FakeSearchClient(),
          ),
          audioEngineProvider.overrideWithValue(_StubAudioEngine()),
          audioDownloaderProvider.overrideWithValue(_StubAudioDownloader()),
          downloadDatabaseProvider.overrideWithValue(
            DownloadDatabase(
              overridePath: p.join(_widgetTestDir.path, 'widget_test.db'),
            ),
          ),
        ],
        child: const PodcastApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('探索'), findsWidgets);
    expect(find.text('台灣熱門 Podcast'), findsOneWidget);
  });
}
