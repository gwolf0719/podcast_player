import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/models/podcast.dart';
import '../../../core/data/models/podcast.dart' as models show Episode;
import '../../../core/data/preview/fake_podcasts.dart';
import '../../../core/data/repositories/episode_repository.dart';
import '../../podcast/application/podcast_controller.dart';

final episodeDetailControllerProvider =
    AutoDisposeAsyncNotifierProviderFamily<
      EpisodeDetailController,
      EpisodeDetail?,
      String
    >(EpisodeDetailController.new, name: 'episodeDetailControllerProvider');

class EpisodeDetail {
  const EpisodeDetail({required this.podcast, required this.episode});

  final Podcast podcast;
  final models.Episode episode;
}

class EpisodeDetailController
    extends AutoDisposeFamilyAsyncNotifier<EpisodeDetail?, String> {
  @override
  Future<EpisodeDetail?> build(String episodeId) async {
    final repo = ref.read(episodeRepositoryProvider);
    final stored = await repo.findEpisode(episodeId);
    if (stored != null) {
      final feedUrl = stored.podcastFeedUrl ?? stored.audioUrl;
      final podcast = await ref.read(
        podcastDetailControllerProvider(feedUrl).future,
      );
      if (podcast != null) {
        return EpisodeDetail(podcast: podcast, episode: stored);
      }
      return EpisodeDetail(
        podcast: Podcast(
          id: feedUrl,
          title: stored.podcastTitle ?? '未知節目',
          author: stored.podcastAuthor ?? '',
          feedUrl: feedUrl,
          episodes: const [],
        ),
        episode: stored,
      );
    }

    for (final podcast in samplePodcasts) {
      for (final episode in podcast.episodes) {
        if (episode.id == episodeId) {
          return EpisodeDetail(podcast: podcast, episode: episode);
        }
      }
    }
    return null;
  }
}
