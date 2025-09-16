import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../widgets/episode_actions.dart';
import '../../download/application/download_controller.dart';
import '../../../core/data/models/download_task.dart';
import '../application/episode_detail_controller.dart';

class EpisodePage extends ConsumerWidget {
  const EpisodePage({super.key, required this.episodeId});

  final String episodeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncDetail = ref.watch(episodeDetailControllerProvider(episodeId));
    final tasks = ref.watch(downloadControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('單集詳情')),
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

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detail.episode.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  detail.podcast.title,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                EpisodeActions(
                  episode: detail.episode,
                  podcast: detail.podcast,
                  task: task,
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(detail.episode.description ?? '尚無節目內容'),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('載入單集失敗：$error')),
      ),
    );
  }
}
