import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../widgets/episode_actions.dart';
import '../../download/application/download_controller.dart';
import '../../player/application/audio_player_controller.dart';
import '../../player/application/playback_queue_controller.dart';
import '../../../core/data/models/download_task.dart';
import '../application/episode_detail_controller.dart';

class EpisodePage extends ConsumerWidget {
  const EpisodePage({super.key, required this.episodeId});

  final String episodeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncDetail = ref.watch(episodeDetailControllerProvider(episodeId));
    final tasks = ref.watch(downloadControllerProvider);
    final playerState = ref.watch(audioPlayerControllerProvider);
    final playerController = ref.read(audioPlayerControllerProvider.notifier);

    return Scaffold(
      body: asyncDetail.when(
        data: (detail) {
          if (detail == null) {
            return const Center(child: Text('找不到單集資訊'));
          }
          
          DownloadTask? task;
          for (final element in tasks) {
            if (element.episodeId == detail.episode.id) {
              task = element;
              break;
            }
          }

          final isCurrentEpisode = playerState?.episode.id == detail.episode.id;
          final isPlaying = isCurrentEpisode && playerState?.isPlaying == true;

          return CustomScrollView(
            slivers: [
              // 播放器界面
              SliverAppBar(
                expandedHeight: 400,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    detail.episode.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      shadows: [
                        Shadow(
                          offset: Offset(0, 1),
                          blurRadius: 3,
                          color: Colors.black54,
                        ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
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
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: kToolbarHeight),
                          
                          // 節目封面圖
                          Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: detail.episode.imageUrl != null
                                  ? Image.network(
                                      detail.episode.imageUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return _buildDefaultCover(context);
                                      },
                                    )
                                  : detail.podcast.artworkUrl != null
                                      ? Image.network(
                                          detail.podcast.artworkUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return _buildDefaultCover(context);
                                          },
                                        )
                                      : _buildDefaultCover(context),
                            ),
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // 播放控制
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                IconButton(
                                  onPressed: () => playerController.playPrevious(),
                                  icon: const Icon(Icons.skip_previous),
                                  iconSize: 32,
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                  child: IconButton(
                                    onPressed: () {
                                      if (isCurrentEpisode) {
                                        playerController.togglePlayPause();
                                      } else {
                                        final queueController = ref.read(playbackQueueControllerProvider.notifier);
                                        queueController.playNow(
                                          detail.podcast,
                                          detail.episode,
                                          localFilePath: task?.filePath,
                                        );
                                        playerController.playEpisode(
                                          detail.podcast,
                                          detail.episode,
                                          localFilePath: task?.filePath,
                                        );
                                      }
                                    },
                                    icon: Icon(
                                      isPlaying ? Icons.pause : Icons.play_arrow,
                                      color: Theme.of(context).colorScheme.onPrimary,
                                    ),
                                    iconSize: 48,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => playerController.playNext(),
                                  icon: const Icon(Icons.skip_next),
                                  iconSize: 32,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              
              // 進度條（如果正在播放）
              if (isCurrentEpisode && playerState != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            // 進度條
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                trackHeight: 4,
                              ),
                              child: Slider(
                                value: _getProgressValue(playerState),
                                onChanged: (value) {
                                  // TODO: 實現進度跳轉功能
                                },
                              ),
                            ),
                            // 時間顯示
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatDuration(playerState.position),
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    _formatDuration(playerState.duration),
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              
              // 節目資訊
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
                            '節目資訊',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            detail.podcast.title,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            detail.podcast.author,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (detail.episode.publishedAt != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              '發布時間：${_formatDate(detail.episode.publishedAt!)}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                          if (detail.episode.duration != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              '播放時長：${_formatDuration(detail.episode.duration!)}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              
              // 操作按鈕
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          EpisodeActions(
                            episode: detail.episode,
                            podcast: detail.podcast,
                            task: task,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              
              // 節目描述
              if (detail.episode.description != null && detail.episode.description!.isNotEmpty)
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
                              '節目描述',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(detail.episode.description!),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              
              // 底部空白
              const SliverToBoxAdapter(
                child: SizedBox(height: 100),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('載入單集失敗：$error')),
      ),
    );
  }

  /// 建立預設封面
  Widget _buildDefaultCover(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(
        Icons.music_note,
        size: 80,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  /// 獲取播放進度值
  double _getProgressValue(dynamic playerState) {
    if (playerState.duration.inMilliseconds == 0) {
      return 0.0;
    }
    final progress = playerState.position.inMilliseconds / playerState.duration.inMilliseconds;
    return progress.clamp(0.0, 1.0);
  }

  /// 格式化日期
  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
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
