import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/models/podcast.dart';
import '../../../core/data/models/podcast.dart' as models show Episode;
import '../../../core/data/preview/fake_podcasts.dart';
import '../../../core/data/repositories/episode_repository.dart';
import '../../../core/data/repositories/charts_repository.dart';
import '../../../core/network/podcast_feed_client.dart';
import '../../../core/network/apple_podcasts_search_client.dart';
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
    print('🔍 正在載入 Podcast，ID: $id');
    
    final chartsRepo = ref.read(chartsRepositoryProvider);

    // 先嘗試從樣本資料中查找
    Podcast? base;
    for (final podcast in samplePodcasts) {
      if (podcast.id == id || podcast.feedUrl == id) {
        base = podcast;
        print('✅ 在樣本資料中找到 Podcast: ${podcast.title}');
        break;
      }
    }

    // 如果樣本資料中沒有，嘗試從熱門榜單中查找
    if (base == null) {
      print('⚠️ 樣本資料中未找到，嘗試從熱門榜單查找...');
      try {
        final trendingPodcasts = await chartsRepo.fetchTrendingTW();
        print('📊 獲取到 ${trendingPodcasts.length} 個熱門 Podcast');
        for (final podcast in trendingPodcasts) {
          if (podcast.id == id || podcast.feedUrl == id) {
            base = podcast;
            print('✅ 在熱門榜單中找到 Podcast: ${podcast.title}');
            break;
          }
        }
      } catch (e) {
        print('❌ 無法獲取熱門榜單：$e');
      }
    }

    // 如果找到了基本資訊，嘗試載入真實的節目清單
    if (base != null) {
      print('✅ 找到基本 Podcast 資訊: ${base.title}');
      
      final feedClient = ref.read(podcastFeedClientProvider);
      final episodesRepo = ref.read(episodeRepositoryProvider);
      String? realFeedUrl = base.feedUrl;
      List<models.Episode> episodes = [];
      
      // 如果 feedUrl 是 Apple Podcasts 連結，嘗試使用搜尋 API 獲取真實的 RSS feed
      if (realFeedUrl?.contains('podcasts.apple.com') == true) {
        print('🔍 偵測到 Apple Podcasts 連結，嘗試搜尋真實的 RSS feed...');
        
        try {
          final searchClient = ref.read(applePodcastsSearchClientProvider);
          print('🔍 搜尋關鍵字: "${base.title}"');
          final searchResults = await searchClient.search(base.title);
          print('📊 搜尋結果：${searchResults.podcasts.length} 個 podcast');
          
          // 列出所有搜尋結果以便除錯
          for (int i = 0; i < searchResults.podcasts.length && i < 5; i++) {
            final p = searchResults.podcasts[i];
            print('🔍 結果 $i: "${p.title}" - feedUrl: ${p.feedUrl}');
          }
          
          // 找到匹配的 podcast 並使用其 feedUrl
          for (final searchPodcast in searchResults.podcasts) {
            print('🔍 比較: "${searchPodcast.title}" vs "${base.title}"');
            if (searchPodcast.title.toLowerCase().trim() == base.title.toLowerCase().trim()) {
              if (searchPodcast.feedUrl != null && 
                  searchPodcast.feedUrl!.isNotEmpty &&
                  !searchPodcast.feedUrl!.contains('podcasts.apple.com')) {
                realFeedUrl = searchPodcast.feedUrl!;
                print('✅ 找到完全匹配的真實 RSS feed: $realFeedUrl');
                break;
              }
            }
          }
          
          // 如果找不到完全匹配，嘗試部分匹配
          if (realFeedUrl?.contains('podcasts.apple.com') == true) {
            for (final searchPodcast in searchResults.podcasts) {
              if (searchPodcast.feedUrl != null && 
                  searchPodcast.feedUrl!.isNotEmpty &&
                  !searchPodcast.feedUrl!.contains('podcasts.apple.com')) {
                realFeedUrl = searchPodcast.feedUrl!;
                print('✅ 找到部分匹配的 RSS feed: $realFeedUrl');
                break;
              }
            }
          }
        } catch (e) {
          print('❌ 搜尋 RSS feed 失敗：$e');
        }
      }
      
      // 嘗試從真實的 RSS feed 載入節目清單
      if (realFeedUrl != null && !realFeedUrl.contains('podcasts.apple.com')) {
        try {
          print('📡 正在從真實 RSS feed 獲取節目清單: $realFeedUrl');
          episodes = await feedClient.fetchEpisodes(realFeedUrl);
          print('✅ 成功獲取 ${episodes.length} 個真實節目');
          
          if (episodes.isNotEmpty) {
            // 儲存到資料庫
            await episodesRepo.upsertEpisodes(
              realFeedUrl,
              _augmentEpisodes(base, episodes),
            );
            
            // 從資料庫重新載入以確保資料一致性
            final stored = await episodesRepo.listEpisodes(realFeedUrl);
            episodes = stored;
            print('💾 從資料庫載入 ${stored.length} 個節目');
          }
          
        } catch (e) {
          print('❌ 載入真實 RSS feed 失敗：$e');
          // 嘗試從資料庫載入快取的真實資料
          try {
            final stored = await episodesRepo.listEpisodes(realFeedUrl);
            episodes = stored;
            print('💾 使用快取的真實資料：${stored.length} 個節目');
          } catch (dbError) {
            print('❌ 資料庫載入也失敗：$dbError');
          }
        }
      } else {
        print('⚠️ 無有效的 RSS feed URL，無法載入真實節目清單');
      }
      
      return Podcast(
        id: base.id,
        title: base.title,
        author: base.author,
        feedUrl: realFeedUrl ?? base.feedUrl,
        description: base.description,
        artworkUrl: base.artworkUrl,
        category: base.category,
        language: base.language,
        episodes: episodes,
      );
    }

    print('❌ 無法找到 Podcast 資料');
    return null;
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
