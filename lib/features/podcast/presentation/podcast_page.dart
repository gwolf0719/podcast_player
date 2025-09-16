import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../widgets/episode_actions.dart';
import '../../download/application/download_controller.dart';
import '../../player/application/audio_player_controller.dart';
import '../../player/application/playback_queue_controller.dart';
import '../../../core/navigation/app_router.dart';
import 'package:go_router/go_router.dart';
import '../application/podcast_controller.dart';
import '../../player/presentation/mini_player.dart';
import '../../../core/data/models/download_task.dart';

/// Podcast 詳細頁面
/// 顯示頻道資訊和節目清單，支援播放和加入隊列功能
class PodcastPage extends ConsumerWidget {
  const PodcastPage({super.key, required this.podcastId});

  final String podcastId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncPodcast = ref.watch(podcastDetailControllerProvider(podcastId));
    final tasks = ref.watch(downloadControllerProvider);
    final taskByEpisodeId = {for (final task in tasks) task.episodeId: task};

    return Scaffold(
      body: asyncPodcast.when(
        data: (podcast) {
          if (podcast == null) {
            return const Center(child: Text('找不到節目資訊'));
          }

          // 按發布時間排序：最新的在前面
          final sortedEpisodes = [...podcast.episodes];
          sortedEpisodes.sort((a, b) {
            if (a.publishedAt == null && b.publishedAt == null) return 0;
            if (a.publishedAt == null) return 1;
            if (b.publishedAt == null) return -1;
            return b.publishedAt!.compareTo(a.publishedAt!); // 新的在前
          });

          return CustomScrollView(
            slivers: [
              // 頻道資訊頭部
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Theme.of(context).colorScheme.primaryContainer,
                          Theme.of(context).colorScheme.surface,
                        ],
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // 頻道封面圖
                            if (podcast.artworkUrl != null) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  podcast.artworkUrl!,
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      width: 100,
                                      height: 100,
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.surfaceVariant,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        Icons.radio,
                                        size: 40,
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            
                            // 頻道標題
                            Text(
                              podcast.title,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            
                            // 作者資訊
                            Text(
                              podcast.author,
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            
                            // 節目數量
                            Text(
                              '共 ${sortedEpisodes.length} 集節目',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              
              // 節目描述（如果有的話）
              if (podcast.description != null && podcast.description!.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '關於節目',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(podcast.description!),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              
              // 節目清單標題
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Text(
                    '節目清單',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              
              // 節目清單或空狀態
              if (sortedEpisodes.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 64,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '暫時無法載入節目清單',
                          style: Theme.of(context).textTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '這可能是因為 RSS feed 無法存取或格式不支援。\n請稍後再試或聯絡開發者。',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            // 重新載入
                            ref.invalidate(podcastDetailControllerProvider(podcastId));
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('重新載入'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverList.builder(
                  itemCount: sortedEpisodes.length,
                  itemBuilder: (context, index) {
                    final episode = sortedEpisodes[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        title: Text(
                          episode.title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              if (episode.publishedAt != null) ...[
                                Text(
                                  _formatDate(episode.publishedAt!),
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                if (episode.duration != null) ...[
                                  Text(
                                    ' • ',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  Text(
                                    _formatDuration(episode.duration!),
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ] else if (episode.duration != null) ...[
                                Text(
                                  _formatDuration(episode.duration!),
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        trailing: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 180),
                          child: EpisodeActions(
                            episode: episode,
                            podcast: podcast,
                            task: taskByEpisodeId[episode.id],
                          ),
                        ),
                        onTap: () {
                          // 點選節目標題也會啟動播放並進入內頁
                          final queueController = ref.read(playbackQueueControllerProvider.notifier);
                          final playerController = ref.read(audioPlayerControllerProvider.notifier);
                          final task = taskByEpisodeId[episode.id];
                          final localPath = (task != null && task.status == DownloadStatus.completed)
                              ? task.filePath
                              : null;
                          
                          // 立即播放
                          queueController.playNow(
                            podcast,
                            episode,
                            localFilePath: localPath,
                          );
                          
                          playerController.playEpisode(
                            podcast,
                            episode,
                            localFilePath: localPath,
                          );
                          
                          // 導航到內頁播放器
                          context.pushNamed(
                            EpisodeRoute.name,
                            pathParameters: {'episodeId': episode.id},
                          );
                        },
                      ),
                    );
                  },
                ),
              
              // 底部空白
              const SliverToBoxAdapter(
                child: SizedBox(height: 100),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('載入節目失敗：$error')),
      ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }

  /// 格式化日期
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return '今天';
    } else if (difference.inDays == 1) {
      return '昨天';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} 天前';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()} 週前';
    } else {
      return '${date.year}/${date.month}/${date.day}';
    }
  }

  /// 格式化播放時長
  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    
    if (hours > 0) {
      return '${hours}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes}:${seconds.toString().padLeft(2, '0')}';
    }
  }
}
