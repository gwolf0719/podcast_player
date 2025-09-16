import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/models/podcast.dart';
import '../../../core/data/models/podcast.dart' as models show Episode;
import '../../../core/data/preview/fake_podcasts.dart';
import '../../../core/data/repositories/episode_repository.dart';
import '../../../core/data/repositories/charts_repository.dart';
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
    print('🔍 正在載入節目詳細資訊，ID: $episodeId');
    
    final repo = ref.read(episodeRepositoryProvider);
    final stored = await repo.findEpisode(episodeId);
    if (stored != null) {
      print('✅ 在資料庫中找到節目: ${stored.title}');
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

    // 檢查樣本資料
    for (final podcast in samplePodcasts) {
      for (final episode in podcast.episodes) {
        if (episode.id == episodeId) {
          print('✅ 在樣本資料中找到節目: ${episode.title}');
          return EpisodeDetail(podcast: podcast, episode: episode);
        }
      }
    }

    // 如果節目 ID 是動態生成的，嘗試從熱門榜單重建
    if (episodeId.startsWith('ep-')) {
      print('🔍 偵測到動態節目 ID，嘗試重建...');
      try {
        final chartsRepo = ref.read(chartsRepositoryProvider);
        final trendingPodcasts = await chartsRepo.fetchTrendingTW();
        
        // 嘗試載入每個 podcast 並查找匹配的節目
        for (final podcast in trendingPodcasts) {
          final podcastDetail = await ref.read(
            podcastDetailControllerProvider(podcast.id).future,
          );
          
          if (podcastDetail != null) {
            // 在這個 podcast 的節目中查找
            for (final episode in podcastDetail.episodes) {
              if (episode.id == episodeId) {
                print('✅ 在 ${podcastDetail.title} 中找到節目: ${episode.title}');
                return EpisodeDetail(podcast: podcastDetail, episode: episode);
              }
            }
          }
        }
      } catch (e) {
        print('❌ 從熱門榜單查找節目失敗：$e');
      }
    }
    
    print('❌ 無法找到節目資訊');
    return null;
  }

}
