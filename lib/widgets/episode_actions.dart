import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/data/models/download_task.dart';
import '../core/data/models/podcast.dart';
import '../core/data/models/podcast.dart' as models show Episode;
import '../features/download/application/download_controller.dart';
import '../features/player/application/audio_player_controller.dart';

class EpisodeActions extends ConsumerWidget {
  const EpisodeActions({
    super.key,
    required this.episode,
    this.podcast,
    this.task,
  });

  final models.Episode episode;
  final Podcast? podcast;
  final DownloadTask? task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(audioPlayerControllerProvider);
    final playerController = ref.read(audioPlayerControllerProvider.notifier);
    final isCurrentEpisode = playerState?.episode.id == episode.id;

    final downloadController = ref.read(downloadControllerProvider.notifier);

    return Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        IconButton(
          tooltip: isCurrentEpisode && playerState?.isPlaying == true
              ? '暫停'
              : '播放',
          icon: Icon(
            isCurrentEpisode && playerState?.isPlaying == true
                ? Icons.pause
                : Icons.play_arrow,
          ),
          onPressed: () {
            if (isCurrentEpisode) {
              playerController.togglePlayPause();
              return;
            }
            final hostPodcast =
                podcast ??
                Podcast(
                  id: episode.podcastTitle ?? episode.id,
                  title: episode.podcastTitle ?? '未知節目',
                  author: episode.podcastAuthor ?? '',
                  feedUrl: episode.audioUrl,
                  episodes: const [],
                );
            playerController.playEpisode(
              hostPodcast,
              episode,
              localFilePath: task?.filePath,
            );
          },
        ),
        _DownloadButton(
          episode: episode,
          task: task,
          controller: downloadController,
          podcast: podcast,
        ),
      ],
    );
  }
}

class _DownloadButton extends StatelessWidget {
  const _DownloadButton({
    required this.episode,
    required this.task,
    required this.controller,
    required this.podcast,
  });

  final models.Episode episode;
  final DownloadTask? task;
  final DownloadController controller;
  final Podcast? podcast;

  @override
  Widget build(BuildContext context) {
    final status = task?.status;

    if (status == DownloadStatus.downloading) {
      return SizedBox(
        width: 90,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(value: task?.progress ?? 0),
            const SizedBox(height: 4),
            Text(
              '${((task?.progress ?? 0) * 100).round()}%',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: '暫停下載',
                  iconSize: 18,
                  onPressed: () => controller.pauseDownload(task!.id),
                  icon: const Icon(Icons.pause),
                ),
                IconButton(
                  tooltip: '取消下載',
                  iconSize: 18,
                  onPressed: () => controller.cancelDownload(task!.id),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (status == DownloadStatus.paused) {
      return IconButton(
        tooltip: '繼續下載',
        icon: const Icon(Icons.play_arrow),
        onPressed: () => controller.resumeDownload(task!.id),
      );
    }

    if (status == DownloadStatus.queued) {
      return IconButton(
        tooltip: task?.errorMessage ?? '等待下載',
        onPressed: () => controller.cancelDownload(task!.id),
        icon: const Icon(Icons.schedule),
      );
    }

    if (status == DownloadStatus.completed) {
      return IconButton(
        tooltip: '移除下載',
        icon: const Icon(Icons.check_circle, color: Colors.green),
        onPressed: () => controller.removeTask(task!.id),
      );
    }

    if (status == DownloadStatus.failed || status == DownloadStatus.canceled) {
      return IconButton(
        tooltip: '重試下載',
        icon: const Icon(Icons.refresh),
        onPressed: () => controller.retry(task!.id),
      );
    }

    return IconButton(
      tooltip: '下載',
      icon: const Icon(Icons.download_for_offline_outlined),
      onPressed: () {
        final hostPodcast =
            podcast ??
            Podcast(
              id: episode.podcastTitle ?? episode.id,
              title: episode.podcastTitle ?? '未知節目',
              author: episode.podcastAuthor ?? '',
              feedUrl: episode.audioUrl,
              episodes: const [],
            );
        controller.startDownload(hostPodcast, episode);
      },
    );
  }
}
