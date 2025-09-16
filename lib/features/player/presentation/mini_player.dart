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
