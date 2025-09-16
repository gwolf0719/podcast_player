import 'package:flutter/material.dart';

import '../core/data/models/podcast.dart';

/// Podcast 卡片元件
/// 顯示 Podcast 的基本資訊，包括封面圖、標題、作者等

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
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Podcast 封面圖
                if (podcast.artworkUrl != null) ...[
                  Expanded(
                    flex: 3,
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 1.0, // 保持正方形比例
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            podcast.artworkUrl!,
                            fit: BoxFit.cover, // 裁剪以填滿容器，保持圖片比例
                            width: double.infinity,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: double.infinity,
                            color: theme.colorScheme.surfaceVariant,
                            child: Icon(
                              Icons.radio,
                              size: 32,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          );
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            height: double.infinity,
                            color: theme.colorScheme.surfaceVariant,
                            child: Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                                strokeWidth: 2,
                              ),
                            ),
                          );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                // Podcast 資訊區域
                Expanded(
                  flex: 2,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 標題
                      Text(
                        podcast.title,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 2),
                      // 作者
                      Text(
                        podcast.author,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 10,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                      const Spacer(),
                      // 訂閱按鈕
                      SizedBox(
                        height: 28,
                        child: FilledButton.tonalIcon(
                          onPressed: onToggleSubscription == null
                              ? null
                              : () async {
                                  await onToggleSubscription!();
                                },
                          icon: Icon(
                            isSubscribed ? Icons.check : Icons.add,
                            size: 14,
                          ),
                          label: Text(
                            isSubscribed ? '已訂閱' : '訂閱',
                            style: const TextStyle(fontSize: 12),
                          ),
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
    );
  }
}
