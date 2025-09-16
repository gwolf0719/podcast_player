/// 這個檔案負責：
/// - 迷你播放器 UI：顯示標題/作者、播放/暫停、停止與進度
/// - 提供播放模式選擇（依序、隨機、單集）
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/audio_player_controller.dart';
import '../application/playback_state.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(audioPlayerControllerProvider);
    if (state == null) {
      return const SizedBox.shrink();
    }

    final controller = ref.read(audioPlayerControllerProvider.notifier);
    final progress = _buildProgressValue(state);

    return Material(
      elevation: 4,
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (progress != null) LinearProgressIndicator(value: progress),
          ListTile(
            leading: CircleAvatar(
              child: Icon(state.isPlaying ? Icons.equalizer : Icons.podcasts),
            ),
            title: Text(
              state.episode.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              state.podcast.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Wrap(
              spacing: 12,
              children: [
                if (state.errorMessage != null)
                  Icon(
                    Icons.error_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                const _ModeButton(),
                IconButton(
                  tooltip: state.isPlaying ? '暫停' : '播放',
                  icon: Icon(state.isPlaying ? Icons.pause : Icons.play_arrow),
                  onPressed: controller.togglePlayPause,
                ),
                IconButton(
                  tooltip: '停止播放',
                  icon: const Icon(Icons.close),
                  onPressed: controller.stop,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double? _buildProgressValue(PlaybackState state) {
    if (state.duration.inMilliseconds == 0) {
      return null;
    }
    final progress =
        state.position.inMilliseconds / state.duration.inMilliseconds;
    if (progress.isNaN || progress.isInfinite) {
      return null;
    }
    return progress.clamp(0.0, 1.0);
  }
}

/// 播放模式切換按鈕（彈出選單）
/// 輸入：目前模式 `mode`
/// 輸出：可選依序/隨機/單集三種模式
class _ModeButton extends ConsumerWidget {
  const _ModeButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(audioPlayerControllerProvider.notifier);
    final s = ref.watch(audioPlayerControllerProvider);
    // 防禦：熱重載舊狀態可能沒有 mode 欄位，提供預設值
    PlaybackMode mode;
    try {
      mode = s?.mode ?? PlaybackMode.sequential;
    } catch (_) {
      mode = PlaybackMode.sequential;
    }
    return PopupMenuButton<PlaybackMode>(
      tooltip: '播放模式',
      icon: Icon(_iconFor(mode)),
      onSelected: controller.setMode,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: PlaybackMode.sequential,
          child: Row(
            children: [
              Icon(_iconFor(PlaybackMode.sequential)),
              const SizedBox(width: 8),
              const Text('依序播放'),
              if (mode == PlaybackMode.sequential) ...[
                const Spacer(),
                const Icon(Icons.check, size: 16),
              ],
            ],
          ),
        ),
        PopupMenuItem(
          value: PlaybackMode.shuffle,
          child: Row(
            children: [
              Icon(_iconFor(PlaybackMode.shuffle)),
              const SizedBox(width: 8),
              const Text('隨機播放'),
              if (mode == PlaybackMode.shuffle) ...[
                const Spacer(),
                const Icon(Icons.check, size: 16),
              ],
            ],
          ),
        ),
        PopupMenuItem(
          value: PlaybackMode.single,
          child: Row(
            children: [
              Icon(_iconFor(PlaybackMode.single)),
              const SizedBox(width: 8),
              const Text('單集播放（結束即停）'),
              if (mode == PlaybackMode.single) ...[
                const Spacer(),
                const Icon(Icons.check, size: 16),
              ],
            ],
          ),
        ),
      ],
    );
  }

  IconData _iconFor(PlaybackMode mode) {
    switch (mode) {
      case PlaybackMode.sequential:
        return Icons.queue_music;
      case PlaybackMode.shuffle:
        return Icons.shuffle;
      case PlaybackMode.single:
        return Icons.looks_one;
    }
  }
}
