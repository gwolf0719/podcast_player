import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/models/podcast.dart';
import '../../library/application/subscription_controller.dart';
import '../../../widgets/podcast_card.dart';
import 'discover_controller.dart';
import 'discover_filter_controller.dart';
import '../../../core/navigation/app_router.dart';

class DiscoverPage extends ConsumerWidget {
  const DiscoverPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(discoverControllerProvider);

    return state.when(
      data: (podcasts) => _DiscoverContent(podcasts: podcasts),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => _DiscoverError(
        message: '熱門排行榜載入失敗，請稍後再試。',
        onRetry: () => ref.read(discoverControllerProvider.notifier).refresh(),
      ),
    );
  }
}

class _DiscoverContent extends ConsumerWidget {
  const _DiscoverContent({required this.podcasts});

  final List<Podcast> podcasts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscriptions = ref.watch(subscriptionControllerProvider);
    final subscriptionController = ref.read(
      subscriptionControllerProvider.notifier,
    );
    final filterState = ref.watch(discoverFilterControllerProvider);
    final filterController =
        ref.read(discoverFilterControllerProvider.notifier);
    final subscribedFeeds = subscriptions
        .map((podcast) => podcast.feedUrl)
        .toSet();

    final categoryOptions = _buildCategoryOptions(podcasts);
    final filteredPodcasts = _applyFilters(
      podcasts,
      filterState,
    );

    return RefreshIndicator(
      onRefresh: () => ref.read(discoverControllerProvider.notifier).refresh(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 720;
          final crossAxisCount = isWide ? 3 : 1;
          final cardWidth = isWide
              ? (constraints.maxWidth - ((crossAxisCount - 1) * 16)) /
                    crossAxisCount
              : constraints.maxWidth;

          if (podcasts.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [_DiscoverEmptyView()],
            );
          }

          if (filteredPodcasts.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                _DiscoverEmptyView(
                  message: '找不到符合條件的熱門節目，請調整篩選條件。',
                ),
              ],
            );
          }

          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '台灣熱門 Podcast',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '資料來源：Apple Podcasts 熱門排行榜（每日快取 24 小時）。',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: _DiscoverFilters(
                    categories: categoryOptions,
                    state: filterState,
                    onCategoryChanged: filterController.updateCategory,
                    onSortChanged: (option) {
                      if (option != null) {
                        filterController.updateSortOption(option);
                      }
                    },
                    onReset: filterController.reset,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    mainAxisExtent: 210,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final podcast = filteredPodcasts[index];
                    final isSubscribed = subscribedFeeds.contains(
                      podcast.feedUrl,
                    );
                      return PodcastCard(
                        podcast: podcast,
                        width: cardWidth,
                        isSubscribed: isSubscribed,
                        onToggleSubscription: () async {
                          if (isSubscribed) {
                            await subscriptionController
                                .unsubscribe(podcast.feedUrl);
                          } else {
                            await subscriptionController.subscribe(podcast);
                          }
                        },
                        onTap: () => context.pushNamed(
                          PodcastRoute.name,
                          pathParameters: {'podcastId': podcast.id},
                      ),
                    );
                  }, childCount: filteredPodcasts.length),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<String> _buildCategoryOptions(List<Podcast> items) {
    final categories = <String>{};
    for (final podcast in items) {
      if (podcast.category != null && podcast.category!.trim().isNotEmpty) {
        categories.add(podcast.category!.trim());
      }
    }
    return categories.toList()..sort();
  }

  List<Podcast> _applyFilters(
    List<Podcast> source,
    DiscoverFilterState filter,
  ) {
    final list = <Podcast>[];
    for (final podcast in source) {
      if (filter.selectedCategory != null) {
        final category = podcast.category?.trim();
        if (category != filter.selectedCategory) {
          continue;
        }
      }
      list.add(podcast);
    }

    if (filter.sortOption == DiscoverSortOption.title) {
      list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    }

    return list;
  }
}

class _DiscoverFilters extends StatelessWidget {
  const _DiscoverFilters({
    required this.categories,
    required this.state,
    required this.onCategoryChanged,
    required this.onSortChanged,
    required this.onReset,
  });

  final List<String> categories;
  final DiscoverFilterState state;
  final void Function(String?) onCategoryChanged;
  final void Function(DiscoverSortOption?) onSortChanged;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (categories.isNotEmpty) ...[
          Text('熱門分類', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: const Text('全部'),
                    selected: state.selectedCategory == null,
                    onSelected: (_) => onCategoryChanged(null),
                  ),
                ),
                ...categories.map(
                  (category) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(category),
                      selected: state.selectedCategory == category,
                      onSelected: (_) => onCategoryChanged(category),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        Text('排序與其他設定', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<DiscoverSortOption>(
                value: state.sortOption,
                decoration: const InputDecoration(
                  labelText: '排序方式',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem<DiscoverSortOption>(
                    value: DiscoverSortOption.ranking,
                    child: Text('依熱門排名'),
                  ),
                  DropdownMenuItem<DiscoverSortOption>(
                    value: DiscoverSortOption.title,
                    child: Text('依節目名稱'),
                  ),
                ],
                onChanged: onSortChanged,
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: onReset,
              icon: const Icon(Icons.refresh),
              label: const Text('重設條件'),
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _DiscoverEmptyView extends StatelessWidget {
  const _DiscoverEmptyView({
    this.message = '目前沒有熱門節目資料',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.rss_feed_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(message, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            '稍後再試或下拉重新整理。',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _DiscoverError extends StatelessWidget {
  const _DiscoverError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

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
            ElevatedButton(onPressed: onRetry, child: const Text('重新整理')),
          ],
        ),
      ),
    );
  }
}
