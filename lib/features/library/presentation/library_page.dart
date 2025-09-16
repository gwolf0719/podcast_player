/// 這個檔案負責：
/// - 資料庫（Library）頁的 UI 呈現：訂閱、下載、播放清單
/// - 訂閱分頁支援點擊項目導向頻道內容頁
/// - 匯入/匯出 OPML 與下載任務管理
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/models/podcast.dart';
import '../../../core/data/models/download_task.dart';
import '../../../core/data/services/opml_service.dart';
import '../../download/application/download_controller.dart';
import '../application/subscription_controller.dart';
import '../../../core/navigation/app_router.dart';

class LibraryPage extends ConsumerWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscriptions = ref.watch(subscriptionControllerProvider);

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: '訂閱'),
              Tab(text: '下載'),
              Tab(text: '播放清單'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _SubscriptionsTab(
                  subscriptions: subscriptions,
                  onUnsubscribe: (feedUrl) => ref
                      .read(subscriptionControllerProvider.notifier)
                      .unsubscribe(feedUrl),
                  onImport: () => _importOpml(context, ref),
                  onExport: () => _exportOpml(context, ref, subscriptions),
                ),
                _DownloadsTab(
                  tasks: ref.watch(downloadControllerProvider),
                  onCancel: (id) => ref
                      .read(downloadControllerProvider.notifier)
                      .cancelDownload(id),
                  onRetry: (id) =>
                      ref.read(downloadControllerProvider.notifier).retry(id),
                  onRemove: (id) => ref
                      .read(downloadControllerProvider.notifier)
                      .removeTask(id),
                  onPause: (id) => ref
                      .read(downloadControllerProvider.notifier)
                      .pauseDownload(id),
                  onResume: (id) => ref
                      .read(downloadControllerProvider.notifier)
                      .resumeDownload(id),
                  onToggleProtection: (id) => ref
                      .read(downloadControllerProvider.notifier)
                      .toggleProtection(id),
                ),
                const _LibraryPlaceholder(
                  icon: Icons.playlist_play,
                  title: '建立你的播放清單',
                  description: '智慧清單與手動清單目前僅提供規格展示。',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportOpml(
    BuildContext context,
    WidgetRef ref,
    List<Podcast> podcasts,
  ) async {
    if (podcasts.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('目前沒有可匯出的訂閱節目。')));
      return;
    }

    final opmlService = ref.read(opmlServiceProvider);
    final opmlContent = opmlService.exportToOpml(podcasts);

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('匯出 OPML'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(child: SelectableText(opmlContent)),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: opmlContent));
                Navigator.of(context).pop();
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('已複製 OPML 到剪貼簿')));
              },
              child: const Text('複製'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('關閉'),
            ),
          ],
        );
      },
    );
    if (!context.mounted) {
      return;
    }
  }

  Future<void> _importOpml(BuildContext context, WidgetRef ref) async {
    final textController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('匯入 OPML'),
          content: SizedBox(
            width: double.maxFinite,
            child: TextField(
              controller: textController,
              maxLines: 10,
              decoration: const InputDecoration(
                hintText: '貼上 OPML 內容或 RSS 清單',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(textController.text.trim()),
              child: const Text('匯入'),
            ),
          ],
        );
      },
    );
    textController.dispose();

    if (result == null || result.isEmpty) {
      return;
    }

    if (!context.mounted) {
      return;
    }

    final opmlService = ref.read(opmlServiceProvider);
    final controller = ref.read(subscriptionControllerProvider.notifier);

    try {
      final items = opmlService.importFromOpml(result);
      var added = 0;
      for (final podcast in items) {
        if (!controller.isSubscribed(podcast.feedUrl)) {
          await controller.subscribe(podcast);
          added += 1;
        }
      }
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('匯入完成，共新增 $added 個節目。')));
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('匯入失敗：$error')));
    }
  }
}

class _SubscriptionsTab extends StatelessWidget {
  const _SubscriptionsTab({
    required this.subscriptions,
    required this.onUnsubscribe,
    required this.onImport,
    required this.onExport,
  });

  final List<Podcast> subscriptions;
  final Future<void> Function(String feedUrl) onUnsubscribe;
  final Future<void> Function() onImport;
  final Future<void> Function() onExport;

  @override
  Widget build(BuildContext context) {
    if (subscriptions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.subscriptions_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              Text('尚未新增訂閱', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                '探索或匯入 OPML 後即可在這裡管理訂閱的節目。',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => onImport(),
                icon: const Icon(Icons.file_download_outlined),
                label: const Text('匯入 OPML'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              FilledButton.icon(
                onPressed: onImport,
                icon: const Icon(Icons.file_download_outlined),
                label: const Text('匯入'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () => onExport(),
                icon: const Icon(Icons.file_upload_outlined),
                label: const Text('匯出'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemBuilder: (context, index) {
              final podcast = subscriptions[index];
              // 右划退訂：以 Dismissible 取代按鈕刪除
              return Dismissible(
                key: ValueKey('sub_${podcast.feedUrl}'),
                direction: DismissDirection.startToEnd,
                background: _buildDismissBackground(context, label: '退訂'),
                onDismissed: (_) {
                  onUnsubscribe(podcast.feedUrl);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('已退訂：${podcast.title}')),
                  );
                },
                child: Card(
                  child: ListTile(
                    leading: const Icon(Icons.podcasts),
                    title: Text(podcast.title),
                    subtitle: Text(
                      podcast.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // 點擊訂閱項目以進入頻道內容頁
                    onTap: () {
                      context.pushNamed(
                        PodcastRoute.name,
                        pathParameters: {'podcastId': podcast.id},
                      );
                    },
                  ),
                ),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemCount: subscriptions.length,
          ),
        ),
      ],
    );
  }
}

class _LibraryPlaceholder extends StatelessWidget {
  const _LibraryPlaceholder({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

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
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              description,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _DownloadsTab extends StatelessWidget {
  const _DownloadsTab({
    required this.tasks,
    required this.onCancel,
    required this.onRetry,
    required this.onRemove,
    required this.onPause,
    required this.onResume,
    required this.onToggleProtection,
  });

  final List<DownloadTask> tasks;
  final void Function(String) onCancel;
  final void Function(String) onRetry;
  final void Function(String) onRemove;
  final void Function(String) onPause;
  final void Function(String) onResume;
  final void Function(String) onToggleProtection;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return const _LibraryPlaceholder(
        icon: Icons.download_outlined,
        title: '沒有下載中的單集',
        description: '從搜尋或探索頁下載後，會在這裡顯示進度與狀態。',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final task = tasks[index];

        // 右划刪除/取消：使用 Dismissible 控制刪除類動作
        return Dismissible(
          key: ValueKey('dl_${task.id}'),
          direction: DismissDirection.startToEnd,
          background: _buildDismissBackground(
            context,
            label: _dismissLabelFor(task.status),
          ),
          onDismissed: (_) {
            switch (task.status) {
              case DownloadStatus.downloading:
              case DownloadStatus.queued:
                onCancel(task.id);
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('已取消下載')));
                break;
              case DownloadStatus.completed:
              case DownloadStatus.paused:
              case DownloadStatus.failed:
              case DownloadStatus.canceled:
                onRemove(task.id);
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('已移除下載任務')));
                break;
            }
          },
          child: Card(
            child: ListTile(
              leading: Icon(_statusIcon(task.status)),
              title: Text(task.episodeTitle),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(task.podcastTitle),
                  const SizedBox(height: 4),
                  _buildProgressRow(context, task),
                ],
              ),
              trailing: _buildActions(task),
            ),
          ),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemCount: tasks.length,
    );
  }

  Widget _buildProgressRow(BuildContext context, DownloadTask task) {
    switch (task.status) {
      case DownloadStatus.downloading:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(value: task.progress),
            const SizedBox(height: 4),
            Text(
              '下載中 ${(task.progress * 100).round()}%',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        );
      case DownloadStatus.completed:
        return Text('已完成', style: Theme.of(context).textTheme.bodySmall);
      case DownloadStatus.paused:
        return Text('已暫停', style: Theme.of(context).textTheme.bodySmall);
      case DownloadStatus.canceled:
        return Text('已取消', style: Theme.of(context).textTheme.bodySmall);
      case DownloadStatus.failed:
        return Text(
          '下載失敗：${task.errorMessage ?? '未知錯誤'}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.error,
          ),
        );
      case DownloadStatus.queued:
        final message = task.errorMessage ?? '等待下載';
        return Text(
          message,
          style: Theme.of(context).textTheme.bodySmall,
        );
    }
  }

  Widget _buildActions(DownloadTask task) {
    final protectButton = IconButton(
      tooltip: task.isProtected ? '取消保留' : '保留此檔案',
      icon: Icon(task.isProtected ? Icons.star : Icons.star_border),
      onPressed: () => onToggleProtection(task.id),
    );
    switch (task.status) {
      case DownloadStatus.downloading:
        return Wrap(
          spacing: 8,
          children: [
            protectButton,
            IconButton(
              tooltip: '暫停下載',
              icon: const Icon(Icons.pause),
              onPressed: () => onPause(task.id),
            ),
          ],
        );
      case DownloadStatus.paused:
        return Wrap(
          spacing: 8,
          children: [
            protectButton,
            IconButton(
              tooltip: '繼續下載',
              icon: const Icon(Icons.play_arrow),
              onPressed: () => onResume(task.id),
            ),
          ],
        );
      case DownloadStatus.queued:
        return Wrap(
          spacing: 8,
          children: [
            protectButton,
          ],
        );
      case DownloadStatus.completed:
        return Wrap(
          spacing: 8,
          children: [
            protectButton,
          ],
        );
      case DownloadStatus.failed:
      case DownloadStatus.canceled:
        return Wrap(
          spacing: 8,
          children: [
            protectButton,
            IconButton(
              tooltip: '重試',
              icon: const Icon(Icons.refresh),
              onPressed: () => onRetry(task.id),
            ),
          ],
        );
    }
  }

  /// 右划刪除/取消的背景樣式
  /// 輸入：`label` 顯示動作文字
  /// 輸出：帶有圖示與錯誤色的輔助背景
  Widget _buildDismissBackground(BuildContext context, {required String label}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: scheme.errorContainer,
      child: Row(
        children: [
          Icon(Icons.delete_outline, color: scheme.onErrorContainer),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: scheme.onErrorContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// 根據下載狀態決定右划的提示文字
  String _dismissLabelFor(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.downloading:
        return '取消下載';
      case DownloadStatus.queued:
        return '取消排隊';
      case DownloadStatus.completed:
      case DownloadStatus.paused:
      case DownloadStatus.failed:
      case DownloadStatus.canceled:
        return '移除';
    }
  }

  IconData _statusIcon(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.downloading:
        return Icons.downloading;
      case DownloadStatus.paused:
        return Icons.pause_circle_outline;
      case DownloadStatus.completed:
        return Icons.check_circle_outline;
      case DownloadStatus.failed:
        return Icons.error_outline;
      case DownloadStatus.canceled:
        return Icons.stop_circle_outlined;
      case DownloadStatus.queued:
        return Icons.schedule;
    }
  }
}

/// 通用的 Dismissible 背景（退訂/刪除提示）
/// 輸入：`label` 顯示文字
/// 輸出：錯誤色背景＋刪除圖示
Widget _buildDismissBackground(BuildContext context, {required String label}) {
  final scheme = Theme.of(context).colorScheme;
  return Container(
    alignment: Alignment.centerLeft,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    color: scheme.errorContainer,
    child: Row(
      children: [
        Icon(Icons.delete_outline, color: scheme.onErrorContainer),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: scheme.onErrorContainer,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}
