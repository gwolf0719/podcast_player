/// 這個檔案負責：
/// - 單集詳情頁（播放內頁）的 UI 排版
/// - 顯示封面、播放控制、進度、節目資訊、操作按鈕與描述
/// - 採用穩定非重疊的結構，適配小螢幕避免溢位
///
/// 對應測試環境：Android Auto、Pixel 9 XL 模擬器
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../widgets/episode_actions.dart';
import '../../download/application/download_controller.dart';
import '../../player/application/audio_player_controller.dart';
import '../../player/application/playback_queue_controller.dart';
import '../../player/presentation/mini_player.dart';
import '../../../core/data/models/download_task.dart';
import '../application/episode_detail_controller.dart';

/// 單集播放內頁（Episode 詳細頁）
/// 目的：
/// - 提供穩定不重疊的版面（移除重疊風險的 SliverAppBar 彈性空間）
/// - 呈現封面、播放控制、進度、基本資訊、操作與描述
/// 輸入：`episodeId`（字串）
/// 輸出：完整互動頁面（Scaffold）
class EpisodePage extends ConsumerWidget {
  const EpisodePage({super.key, required this.episodeId});

  final String episodeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncDetail = ref.watch(episodeDetailControllerProvider(episodeId));
    final tasks = ref.watch(downloadControllerProvider);
    final playerState = ref.watch(audioPlayerControllerProvider);
    final playerController = ref.read(audioPlayerControllerProvider.notifier);

    return asyncDetail.when(
      data: (detail) {
        if (detail == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('單集詳情')),
            body: const Center(child: Text('找不到單集資訊')),
          );
        }

        DownloadTask? task;
        for (final element in tasks) {
          if (element.episodeId == detail.episode.id) {
            task = element;
            break;
          }
        }

        final isCurrent = playerState?.episode.id == detail.episode.id;
        final isPlaying = isCurrent && playerState?.isPlaying == true;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              detail.episode.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            centerTitle: false,
          ),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final coverSize = constraints.maxWidth.clamp(160.0, 260.0);
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 封面
                      _CoverImage(
                        size: coverSize,
                        imageUrl: detail.episode.imageUrl ?? detail.podcast.artworkUrl,
                      ),
                      const SizedBox(height: 16),

                      // 播放控制
                      _PlaybackControls(
                        isPlaying: isPlaying,
                        onPlayPause: () {
                          if (isCurrent) {
                            playerController.togglePlayPause();
                          } else {
                            final queue = ref.read(playbackQueueControllerProvider.notifier);
                            final localPath = (task != null && task!.status == DownloadStatus.completed)
                                ? task!.filePath
                                : null;
                            queue.playNow(
                              detail.podcast,
                              detail.episode,
                              localFilePath: localPath,
                            );
                            playerController.playEpisode(
                              detail.podcast,
                              detail.episode,
                              localFilePath: localPath,
                            );
                          }
                        },
                        onNext: playerController.playNext,
                        onPrevious: playerController.playPrevious,
                      ),

                      // 進度區（僅在當前播放）
                      if (isCurrent && playerState != null) ...[
                        const SizedBox(height: 8),
                        _ProgressSection(
                          position: playerState.position,
                          duration: playerState.duration,
                          onSeek: (ratio) {
                            // TODO: 若有 Engine 支援，實作 seek
                          },
                          formatter: _formatDuration,
                        ),
                      ],

                      const SizedBox(height: 16),

                      // 基本資訊
                      _InfoSection(
                        podcastTitle: detail.podcast.title,
                        podcastAuthor: detail.podcast.author,
                        publishedAt: detail.episode.publishedAt,
                        duration: detail.episode.duration,
                        dateFormatter: _formatDate,
                        durationFormatter: _formatDuration,
                      ),

                      const SizedBox(height: 12),

                      // 操作按鈕（自動換行避免溢位）
                      _ActionsSection(
                        child: EpisodeActions(
                          episode: detail.episode,
                          podcast: detail.podcast,
                          task: task,
                        ),
                      ),

                      // 描述
                      if ((detail.episode.description ?? '').isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _DescriptionSection(text: detail.episode.description!),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
          bottomNavigationBar: const MiniPlayer(),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => Scaffold(
        appBar: AppBar(title: const Text('單集詳情')),
        body: Center(child: Text('載入單集失敗：$error')),
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

/// 封面元件
/// 輸入：尺寸 `size`、影像網址 `imageUrl`
/// 輸出：方形圓角封面，失敗時顯示預設圖樣
class _CoverImage extends StatelessWidget {
  const _CoverImage({required this.size, this.imageUrl});

  final double size;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final border = BorderRadius.circular(16);
    return Center(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: border,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: border,
          child: imageUrl != null
              ? Image.network(
                  imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) => _fallback(context),
                )
              : _fallback(context),
        ),
      ),
    );
  }

  Widget _fallback(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceVariant,
      child: Icon(
        Icons.podcasts,
        size: size * 0.35,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// 播放控制元件
/// 輸入：播放狀態 `isPlaying`、三個操作事件
/// 輸出：不溢位的控制列（在小螢幕自動等距縮放）
class _PlaybackControls extends StatelessWidget {
  const _PlaybackControls({
    required this.isPlaying,
    required this.onPlayPause,
    required this.onNext,
    required this.onPrevious,
  });

  final bool isPlaying;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final VoidCallback onPrevious;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: onPrevious,
            icon: const Icon(Icons.skip_previous),
            iconSize: 28,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Center(
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primary,
                ),
                child: IconButton(
                  onPressed: onPlayPause,
                  icon: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: scheme.onPrimary,
                  ),
                  iconSize: 44,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onNext,
            icon: const Icon(Icons.skip_next),
            iconSize: 28,
          ),
        ],
      ),
    );
  }
}

/// 播放進度元件
/// 輸入：當前位置、總長度、拖動回呼與格式化器
/// 輸出：卡片內含細高進度條與兩端時間顯示
class _ProgressSection extends StatelessWidget {
  const _ProgressSection({
    required this.position,
    required this.duration,
    required this.onSeek,
    required this.formatter,
  });

  final Duration position;
  final Duration duration;
  final void Function(double ratio) onSeek;
  final String Function(Duration) formatter;

  @override
  Widget build(BuildContext context) {
    final value = duration.inMilliseconds == 0
        ? 0.0
        : (position.inMilliseconds / duration.inMilliseconds)
            .clamp(0.0, 1.0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                trackHeight: 4,
              ),
              child: Slider(
                value: value,
                onChanged: (v) => onSeek(v),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    formatter(position),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    formatter(duration),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

/// 節目資訊元件
/// 輸入：標題、作者、時間、時長與格式器
/// 輸出：卡片排版，避免文字溢位
class _InfoSection extends StatelessWidget {
  const _InfoSection({
    required this.podcastTitle,
    required this.podcastAuthor,
    required this.publishedAt,
    required this.duration,
    required this.dateFormatter,
    required this.durationFormatter,
  });

  final String podcastTitle;
  final String podcastAuthor;
  final DateTime? publishedAt;
  final Duration? duration;
  final String Function(DateTime) dateFormatter;
  final String Function(Duration) durationFormatter;

  @override
  Widget build(BuildContext context) {
    return Card(
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
              podcastTitle,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              podcastAuthor,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (publishedAt != null) ...[
              const SizedBox(height: 8),
              Text(
                '發布時間：${dateFormatter(publishedAt!)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
            if (duration != null) ...[
              const SizedBox(height: 4),
              Text(
                '播放時長：${durationFormatter(duration!)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 操作按鈕區塊
/// 輸入：放入的子元件（例如 EpisodeActions）
/// 輸出：卡片＋Wrap 確保小螢幕不溢位
class _ActionsSection extends StatelessWidget {
  const _ActionsSection({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [child],
          ),
        ),
      ),
    );
  }
}

/// 節目描述元件
/// 輸入：描述文字 `text`
/// 輸出：多行文字卡片，使用 softWrap 與 ellipsis 避免視覺擁擠
class _DescriptionSection extends StatelessWidget {
  const _DescriptionSection({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
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
            Text(
              text,
              softWrap: true,
            ),
          ],
        ),
      ),
    );
  }
}
