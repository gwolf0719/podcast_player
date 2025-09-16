import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:podcast_player/app.dart';
import 'package:podcast_player/core/audio/audio_engine.dart';
import 'package:podcast_player/core/db/download_database.dart';
import 'package:podcast_player/core/download/audio_downloader.dart';
import 'package:podcast_player/core/data/models/podcast.dart'
    as models
    show Episode;
import 'package:podcast_player/core/data/repositories/episode_repository.dart';
import 'package:podcast_player/core/db/episode_database.dart';
import 'package:podcast_player/core/network/podcast_feed_client.dart';
import 'package:podcast_player/core/data/models/podcast.dart';
import 'package:podcast_player/core/data/models/search_results.dart';
import 'package:podcast_player/core/data/preview/fake_podcasts.dart';
import 'package:podcast_player/core/network/apple_podcasts_search_client.dart';
import 'package:podcast_player/features/discover/presentation/discover_controller.dart';
import 'package:podcast_player/widgets/podcast_card.dart';

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

class _FakeEpisodeRepository extends EpisodeRepository {
  _FakeEpisodeRepository() : super(database: EpisodeDatabase(overridePath: ''));

  final Map<String, models.Episode> _episodes = {};

  @override
  Future<void> upsertEpisodes(
    String feedUrl,
    List<models.Episode> episodes,
  ) async {
    for (final episode in episodes) {
      _episodes[episode.id] = episode;
    }
  }

  @override
  Future<List<models.Episode>> listEpisodes(String feedUrl) async {
    return _episodes.values.toList(growable: false);
  }

  @override
  Future<models.Episode?> findEpisode(String episodeId) async {
    return _episodes[episodeId];
  }
}

class _FakeFeedClient extends PodcastFeedClient {
  _FakeFeedClient() : super(httpClient: http.Client());

  @override
  Future<List<models.Episode>> fetchEpisodes(String feedUrl) async {
    return samplePodcasts.first.episodes;
  }
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

late Directory _navTestDir;

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    _navTestDir = await Directory.systemTemp.createTemp('nav_test');
    PathProviderPlatform.instance = _FakePathProvider(_navTestDir.path);
  });

  tearDownAll(() async {
    if (await _navTestDir.exists()) {
      await _navTestDir.delete(recursive: true);
    }
  });

  testWidgets('初始頁面為探索並可透過底部導覽切換畫面', (tester) async {
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
              overridePath: p.join(_navTestDir.path, 'nav_test.db'),
            ),
          ),
          episodeRepositoryProvider.overrideWithValue(_FakeEpisodeRepository()),
          podcastFeedClientProvider.overrideWithValue(_FakeFeedClient()),
        ],
        child: const PodcastApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('探索'), findsWidgets);
    expect(find.text('台灣熱門 Podcast'), findsOneWidget);

    await tester.tap(find.text('搜尋'));
    await tester.pumpAndSettle();

    expect(find.text('搜尋節目或單集'), findsOneWidget);

    await tester.tap(find.text('資料庫'));
    await tester.pumpAndSettle();

    expect(find.text('訂閱'), findsOneWidget);

    await tester.tap(find.text('設定'));
    await tester.pumpAndSettle();

    expect(find.text('下載與同步'), findsOneWidget);
  });

  testWidgets('搜尋輸入後顯示假資料結果', (tester) async {
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
              overridePath: p.join(_navTestDir.path, 'nav_test.db'),
            ),
          ),
        ],
        child: const PodcastApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('搜尋'));
    await tester.pumpAndSettle();

    final field = find.byType(TextField);
    expect(field, findsOneWidget);

    await tester.enterText(field, 'Swift');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text(samplePodcasts.first.title), findsWidgets);
  });

  testWidgets('搜尋列表可以開啟單集詳情頁', (tester) async {
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
              overridePath: p.join(_navTestDir.path, 'nav_test.db'),
            ),
          ),
        ],
        child: const PodcastApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('搜尋'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Swift');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    await tester.tap(find.text(samplePodcasts.first.episodes.first.title));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('單集詳情'), findsOneWidget);
  });

  testWidgets('熱門頁面訂閱後顯示於資料庫', (tester) async {
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
              overridePath: p.join(_navTestDir.path, 'nav_test.db'),
            ),
          ),
        ],
        child: const PodcastApp(),
      ),
    );
    await tester.pumpAndSettle();

    final subscribeButton = find.descendant(
      of: find.byType(PodcastCard).first,
      matching: find.text('訂閱'),
    );
    await tester.tap(subscribeButton);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    await tester.tap(find.text('資料庫'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('訂閱'), findsOneWidget);
  });
}
