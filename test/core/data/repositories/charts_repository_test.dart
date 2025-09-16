import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:podcast_player/core/data/models/podcast.dart';
import 'package:podcast_player/core/data/repositories/charts_repository.dart';
import 'package:podcast_player/core/db/charts_database.dart';
import 'package:podcast_player/core/network/apple_podcasts_rss_client.dart';

class FakeApplePodcastsRssClient extends ApplePodcastsRssClient {
  FakeApplePodcastsRssClient({required this.onFetch})
    : super(httpClient: http.Client());

  final Future<List<Podcast>> Function({String? genreId, int limit}) onFetch;

  @override
  Future<List<Podcast>> fetchTopPodcasts({String? genreId, int limit = 50}) {
    return onFetch(genreId: genreId, limit: limit);
  }
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('ChartsRepository', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('charts_repo');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    Future<ChartsRepository> createRepository(
      FakeApplePodcastsRssClient client,
    ) async {
      final dbPath = p.join(tempDir.path, 'charts.db');
      final database = ChartsDatabase(overridePath: dbPath);
      final repository = ChartsRepository(
        rssClient: client,
        database: database,
        cacheDuration: const Duration(hours: 24),
        nowBuilder: () => DateTime(2024, 1, 1),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return repository;
    }

    test('使用快取避免重複呼叫資料來源', () async {
      var fetchCount = 0;
      final fakeClient = FakeApplePodcastsRssClient(
        onFetch: ({String? genreId, int limit = 50}) async {
          fetchCount += 1;
          return [
            Podcast(
              id: 'id-$fetchCount',
              title: 'Podcast $fetchCount',
              author: 'Author',
              feedUrl: 'https://example.com/$fetchCount',
              episodes: const [],
            ),
          ];
        },
      );

      final repository = await createRepository(fakeClient);

      final first = await repository.fetchTrendingTW();
      final second = await repository.fetchTrendingTW();

      expect(fetchCount, 1);
      expect(second.first.id, first.first.id);
    });

    test('強制重新整理會忽略快取', () async {
      var fetchCount = 0;
      final fakeClient = FakeApplePodcastsRssClient(
        onFetch: ({String? genreId, int limit = 50}) async {
          fetchCount += 1;
          return [
            Podcast(
              id: 'id-$fetchCount',
              title: 'Podcast $fetchCount',
              author: 'Author',
              feedUrl: 'https://example.com/$fetchCount',
              episodes: const [],
            ),
          ];
        },
      );

      final repository = await createRepository(fakeClient);

      await repository.fetchTrendingTW();
      final refreshed = await repository.fetchTrendingTW(forceRefresh: true);

      expect(fetchCount, 2);
      expect(refreshed.first.id, 'id-2');
    });
  });
}
