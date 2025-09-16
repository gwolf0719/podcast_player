import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/models/search_results.dart';
import '../../../features/download/application/download_controller.dart';
import '../../../widgets/episode_actions.dart';
import '../../../core/navigation/app_router.dart';
import 'search_controller.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  late final TextEditingController _controller;
  ProviderSubscription<SearchState>? _subscription;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(searchControllerProvider).query,
    );
    _subscription = ref.listenManual<SearchState>(searchControllerProvider, (
      previous,
      next,
    ) {
      if (previous?.query != next.query && _controller.text != next.query) {
        _controller.value = TextEditingValue(
          text: next.query,
          selection: TextSelection.collapsed(offset: next.query.length),
        );
      }
    });
  }

  @override
  void dispose() {
    _subscription?.close();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchControllerProvider);
    final notifier = ref.read(searchControllerProvider.notifier);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              labelText: '搜尋節目或單集',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: state.query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        notifier.updateQuery('');
                      },
                    ),
              border: const OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.search,
            onChanged: notifier.updateQuery,
            onSubmitted: (_) => notifier.submit(),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _SearchResultsView(state: state, onRetry: notifier.submit),
          ),
        ],
      ),
    );
  }
}

class _SearchResultsView extends StatelessWidget {
  const _SearchResultsView({required this.state, required this.onRetry});

  final SearchState state;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return state.results.when(
      data: (results) {
        if (!state.hasSearched) {
          return const _SearchEmptyView(
            message: '輸入關鍵字開始搜尋 Apple Podcasts 節目或單集。',
          );
        }

        if (results.isEmpty) {
          return const _SearchEmptyView(
            message: '找不到相關節目或單集，換個關鍵字再試試看。',
            icon: Icons.travel_explore_outlined,
          );
        }

        return _SearchResultList(results: results);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => _SearchErrorView(
        message: '搜尋服務暫時無法使用 (${error.toString()})',
        onRetry: onRetry,
      ),
    );
  }
}

class _SearchResultList extends ConsumerWidget {
  const _SearchResultList({required this.results});

  final SearchResults results;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tasks = ref.watch(downloadControllerProvider);
    final taskByEpisodeId = {for (final task in tasks) task.episodeId: task};

    return ListView(
      children: [
        if (results.podcasts.isNotEmpty) ...[
          Text('節目', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          ...results.podcasts.map(
            (podcast) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: const Icon(Icons.podcasts_outlined),
                title: Text(podcast.title),
                subtitle: Text(
                  podcast.author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(podcast.category ?? '未分類'),
                onTap: () => context.pushNamed(
                  PodcastRoute.name,
                  pathParameters: {'podcastId': podcast.id},
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
        if (results.episodes.isNotEmpty) ...[
          Text('單集', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          ...results.episodes.map(
            (episode) => Card(
              child: ListTile(
                leading: const Icon(Icons.play_circle_outline),
                title: Text(episode.title),
                subtitle: Text(
                  episode.description ?? '尚無節目摘要',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (episode.duration != null)
                      Text(_formatDuration(episode.duration!)),
                    EpisodeActions(
                      episode: episode,
                      task: taskByEpisodeId[episode.id],
                    ),
                  ],
                ),
                onTap: () {
                  context.pushNamed(
                    EpisodeRoute.name,
                    pathParameters: {'episodeId': episode.id},
                  );
                },
              ),
            ),
          ),
        ],
        if (results.podcasts.isEmpty && results.episodes.isEmpty)
          const _SearchEmptyView(
            message: '找不到相關節目或單集，換個關鍵字再試試看。',
            icon: Icons.travel_explore_outlined,
          ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _SearchEmptyView extends StatelessWidget {
  const _SearchEmptyView({
    required this.message,
    this.icon = Icons.search_off_outlined,
  });

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchErrorView extends StatelessWidget {
  const _SearchErrorView({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onRetry, child: const Text('重試')),
          ],
        ),
      ),
    );
  }
}
