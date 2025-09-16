import 'package:flutter/material.dart';

import '../core/data/models/podcast.dart';

class PodcastCard extends StatelessWidget {
  const PodcastCard({
    super.key,
    required this.podcast,
    this.width,
    this.isSubscribed = false,
    this.onToggleSubscription,
    this.onTap,
  });

  final Podcast podcast;
  final double? width;
  final bool isSubscribed;
  final Future<void> Function()? onToggleSubscription;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: width,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      podcast.title,
                      style: theme.textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  podcast.author,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  '共 ${podcast.episodes.length} 集 · ${podcast.category ?? '未分類'}',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonalIcon(
                    onPressed: onToggleSubscription == null
                        ? null
                        : () async {
                            await onToggleSubscription!();
                          },
                    icon: Icon(isSubscribed ? Icons.check : Icons.add),
                    label: Text(isSubscribed ? '已訂閱' : '訂閱'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
