import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:podcast_player/core/data/models/podcast.dart';
import 'package:podcast_player/core/data/models/podcast.dart'
    as models
    show Episode;
import 'package:podcast_player/core/data/repositories/episode_repository.dart';
import 'package:podcast_player/core/db/episode_database.dart';
import 'package:podcast_player/core/network/podcast_feed_client.dart';
import 'package:podcast_player/features/episode/application/episode_detail_controller.dart';

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
    return const [
      models.Episode(
        id: 'swift-talk-001',
        title: 'Episode 1',
        audioUrl: 'https://example.com/audio.mp3',
        podcastTitle: 'Swift Talk 台灣',
        podcastAuthor: 'Swift 社群',
        podcastFeedUrl: 'https://example.com/swift.xml',
      ),
    ];
  }
}

void main() {
  test('episodeDetailController can resolve sample data', () async {
    final container = ProviderContainer(
      overrides: [
        episodeRepositoryProvider.overrideWithValue(_FakeEpisodeRepository()),
        podcastFeedClientProvider.overrideWithValue(_FakeFeedClient()),
      ],
    );
    addTearDown(container.dispose);

    final detail = await container.read(
      episodeDetailControllerProvider('swift-talk-001').future,
    );

    expect(detail, isNotNull);
    expect(detail!.episode.id, 'swift-talk-001');
    expect(detail.podcast.title, contains('Swift'));
  });
}
