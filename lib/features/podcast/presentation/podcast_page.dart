import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../widgets/episode_actions.dart';
import '../../download/application/download_controller.dart';
import '../../../core/navigation/app_router.dart';
import 'package:go_router/go_router.dart';
import '../application/podcast_controller.dart';

class PodcastPage extends ConsumerWidget {
  const PodcastPage({super.key, required this.podcastId});

  final String podcastId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncPodcast = ref.watch(podcastDetailControllerProvider(podcastId));
    final tasks = ref.watch(downloadControllerProvider);
    final taskByEpisodeId = {for (final task in tasks) task.episodeId: task};

    return Scaffold(
      appBar: AppBar(title: const Text('節目詳情')),
      body: asyncPodcast.when(
        data: (podcast) {
          if (podcast == null) {
            return const Center(child: Text('找不到節目資訊'));
          }

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        podcast.title,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        podcast.author,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (podcast.description != null) ...[
                        const SizedBox(height: 12),
                        Text(podcast.description!),
                      ],
                    ],
                  ),
                ),
              ),
              SliverList.builder(
                itemCount: podcast.episodes.length,
                itemBuilder: (context, index) {
                  final episode = podcast.episodes[index];
                  return ListTile(
                    title: Text(episode.title),
                    subtitle: Text(
                      episode.description ?? '尚無節目摘要',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: EpisodeActions(
                      episode: episode,
                      podcast: podcast,
                      task: taskByEpisodeId[episode.id],
                    ),
                    onTap: () => context.pushNamed(
                      EpisodeRoute.name,
                      pathParameters: {'episodeId': episode.id},
                    ),
                  );
                },
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('載入節目失敗：$error')),
      ),
    );
  }
}
