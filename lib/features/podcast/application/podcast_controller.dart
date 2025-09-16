import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/models/podcast.dart';
import '../../../core/data/models/podcast.dart' as models show Episode;
import '../../../core/data/preview/fake_podcasts.dart';
import '../../../core/data/repositories/episode_repository.dart';
import '../../../core/network/podcast_feed_client.dart';
import '../../download/application/download_controller.dart';

final podcastDetailControllerProvider =
    AutoDisposeAsyncNotifierProviderFamily<
      PodcastDetailController,
      Podcast?,
      String
    >(PodcastDetailController.new, name: 'podcastDetailControllerProvider');

class PodcastDetailController
    extends AutoDisposeFamilyAsyncNotifier<Podcast?, String> {
  @override
  Future<Podcast?> build(String podcastId) async {
    return _loadPodcast(podcastId);
  }

  Future<Podcast?> _loadPodcast(String id) async {
    final feedClient = ref.read(podcastFeedClientProvider);
    final episodesRepo = ref.read(episodeRepositoryProvider);

    Podcast? base;
    for (final podcast in samplePodcasts) {
      if (podcast.id == id || podcast.feedUrl == id) {
        base = podcast;
        break;
      }
      if (podcast.episodes.any((episode) => episode.id == id)) {
        base = podcast;
        break;
      }
    }

    final feedUrl = base?.feedUrl ?? id;

    try {
      final episodes = await feedClient.fetchEpisodes(feedUrl);
      await episodesRepo.upsertEpisodes(
        feedUrl,
        _augmentEpisodes(base, episodes),
      );
      final stored = await episodesRepo.listEpisodes(feedUrl);
      if (base == null && stored.isNotEmpty) {
        base = Podcast(
          id: feedUrl,
          title: stored.first.podcastTitle ?? '未知節目',
          author: stored.first.podcastAuthor ?? '',
          feedUrl: feedUrl,
          episodes: stored,
        );
      } else if (base != null) {
        base = Podcast(
          id: base.id,
          title: base.title,
          author: base.author,
          feedUrl: base.feedUrl,
          description: base.description,
          artworkUrl: base.artworkUrl,
          category: base.category,
          language: base.language,
          episodes: stored,
        );
      }
    } catch (_) {
      final stored = await episodesRepo.listEpisodes(feedUrl);
      if (base != null && stored.isNotEmpty) {
        base = Podcast(
          id: base.id,
          title: base.title,
          author: base.author,
          feedUrl: base.feedUrl,
          description: base.description,
          artworkUrl: base.artworkUrl,
          category: base.category,
          language: base.language,
          episodes: stored,
        );
      }
    }

    final resolved = base;
    if (resolved != null && resolved.episodes.isNotEmpty) {
      final downloadController = ref.read(downloadControllerProvider.notifier);
      await downloadController.applyAutoDownloadRules(resolved, resolved.episodes);
    }

    return base;
  }

  List<models.Episode> _augmentEpisodes(
    Podcast? base,
    List<models.Episode> episodes,
  ) {
    return episodes
        .map(
          (episode) => models.Episode(
            id: episode.id,
            title: episode.title,
            audioUrl: episode.audioUrl,
            description: episode.description,
            publishedAt: episode.publishedAt,
            duration: episode.duration,
            imageUrl: episode.imageUrl,
            podcastTitle: base?.title,
            podcastAuthor: base?.author,
            podcastFeedUrl: base?.feedUrl,
          ),
        )
        .toList(growable: false);
  }
}
