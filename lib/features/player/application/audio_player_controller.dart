import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 這個檔案負責：
/// - 播放控制（播放/暫停/停止/下一首/上一首）
/// - 音訊來源管理（串流與已下載檔案的切換）
/// - 自動播放邏輯（依播放模式：依序/隨機/單集）
import '../../../core/audio/audio_engine.dart';
import '../../../core/data/models/podcast.dart';
import '../../../core/data/models/podcast.dart' as models show Episode;
import '../../../core/data/models/download_task.dart';
import 'playback_state.dart';
import 'playback_queue_controller.dart';
import '../../download/application/download_controller.dart';

final audioPlayerControllerProvider =
    NotifierProvider<AudioPlayerController, PlaybackState?>(
      AudioPlayerController.new,
      name: 'audioPlayerControllerProvider',
    );

class AudioPlayerController extends Notifier<PlaybackState?> {
  late final AudioEngine _engine;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<EngineStatus>? _statusSub;
  final _random = Random();

  @override
  PlaybackState? build() {
    _engine = ref.watch(audioEngineProvider);
    ref.onDispose(_cleanupSubscriptions);

    _positionSub = _engine.positionStream.listen((position) {
      final current = state;
      if (current == null) {
        return;
      }
      state = current.copyWith(position: position);
    });

    _durationSub = _engine.durationStream.listen((duration) {
      final current = state;
      if (current == null) {
        return;
      }
      if (duration != null) {
        state = current.copyWith(duration: duration);
      }
    });

    _statusSub = _engine.statusStream.listen((status) {
      final current = state;
      if (current == null) {
        return;
      }
      switch (status.processingState) {
        case EngineProcessingState.loading:
          state = current.copyWith(isLoading: true);
          break;
        case EngineProcessingState.ready:
          state = current.copyWith(isLoading: false, isPlaying: status.playing);
          break;
        case EngineProcessingState.completed:
          state = current.copyWith(
            isLoading: false,
            isPlaying: false,
            position: current.duration,
          );
          // 根據播放模式處理完成事件
          _handleCompleted();
          break;
        case EngineProcessingState.idle:
          state = current.copyWith(isLoading: false, isPlaying: status.playing);
          break;
      }
    });
    // 防禦：熱重載時舊狀態可能沒有 mode 欄位，補上預設值
    try {
      final _ = state?.mode;
    } catch (_) {
      if (state != null) {
        state = state!.copyWith(mode: PlaybackMode.sequential);
      }
    }

    return null;
  }

  Future<void> playEpisode(
    Podcast podcast,
    models.Episode episode, {
    String? localFilePath,
  }) async {
    state = PlaybackState(
      podcast: podcast,
      episode: episode,
      isLoading: true,
      isPlaying: false,
      position: Duration.zero,
      duration: Duration.zero,
    );

    try {
      // 若提供本機檔案路徑但檔案不存在（下載中或被清除），則回退到串流 URL
      String source;
      if (localFilePath != null) {
        final file = File(localFilePath);
        final exists = await file.exists();
        source = exists ? file.uri.toString() : episode.audioUrl;
      } else {
        source = episode.audioUrl;
      }
      await _engine.setSource(
        url: source,
        title: episode.title,
        artist: podcast.author,
        artUri: episode.imageUrl ?? podcast.artworkUrl,
        id: episode.id,
      );
      await _engine.play();
      state = state?.copyWith(
        isLoading: false,
        isPlaying: true,
        errorMessage: null,
      );
    } catch (error) {
      state = state?.copyWith(
        isLoading: false,
        isPlaying: false,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> togglePlayPause() async {
    final current = state;
    if (current == null) {
      return;
    }

    if (current.isPlaying) {
      await _engine.pause();
      state = current.copyWith(isPlaying: false);
    } else {
      // 嘗試在恢復播放時切換為本機檔（若已完成下載）
      String? localPath;
      try {
        final tasks = ref.read(downloadControllerProvider);
        for (final t in tasks) {
          if (t.episodeId == current.episode.id &&
              t.status == DownloadStatus.completed &&
              t.filePath != null) {
            localPath = t.filePath;
            break;
          }
        }
      } catch (_) {}

      if (localPath != null) {
        try {
          await _engine.setSource(
            url: Uri.file(localPath).toString(),
            title: current.episode.title,
            artist: current.podcast.author,
            artUri: current.episode.imageUrl ?? current.podcast.artworkUrl,
            id: current.episode.id,
          );
          await _engine.seek(current.position);
          await _engine.play();
          state = current.copyWith(isPlaying: true);
          return;
        } catch (_) {
          // 若切換失敗，回退為直接繼續播放
        }
      }

      await _engine.play();
      state = current.copyWith(isPlaying: true);
    }
  }

  Future<void> stop() async {
    await _engine.stop();
    state = null;
  }

  /// 播放下一首（從隊列）
  Future<void> playNext() async {
    final queueController = ref.read(playbackQueueControllerProvider.notifier);
    final nextEpisode = queueController.moveToNext();
    
    if (nextEpisode != null) {
      await playEpisode(
        nextEpisode.podcast,
        nextEpisode.episode,
        localFilePath: nextEpisode.localFilePath,
      );
    }
  }

  /// 播放上一首（從隊列）
  Future<void> playPrevious() async {
    final queueController = ref.read(playbackQueueControllerProvider.notifier);
    final previousEpisode = queueController.moveToPrevious();
    
    if (previousEpisode != null) {
      await playEpisode(
        previousEpisode.podcast,
        previousEpisode.episode,
        localFilePath: previousEpisode.localFilePath,
      );
    }
  }

  /// 自動播放下一首（內部使用）
  Future<void> _playNextInQueue() async {
    final queue = ref.read(playbackQueueControllerProvider);
    if (queue.hasNext) {
      await playNext();
    }
  }

  /// 當單集播放完成時根據播放模式決定下一步
  Future<void> _handleCompleted() async {
    final current = state;
    if (current == null) return;

    switch (current.mode) {
      case PlaybackMode.single:
        // 單集模式：播放結束直接停止，不自動跳下一首
        return;
      case PlaybackMode.sequential:
        await _playNextInQueue();
        return;
      case PlaybackMode.shuffle:
        final queueController = ref.read(playbackQueueControllerProvider.notifier);
        final queue = ref.read(playbackQueueControllerProvider);
        if (queue.length <= 1) {
          return; // 沒得隨機
        }
        // 隨機挑選一個非當前索引
        final currentIndex = queue.currentIndex;
        final candidates = List<int>.generate(queue.length, (i) => i)
            .where((i) => i != currentIndex)
            .toList();
        if (candidates.isEmpty) return;
        final pick = candidates[_random.nextInt(candidates.length)];
        final next = queueController.moveToIndex(pick);
        if (next != null) {
          await playEpisode(
            next.podcast,
            next.episode,
            localFilePath: next.localFilePath,
          );
        }
        return;
    }
  }

  void _cleanupSubscriptions() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _statusSub?.cancel();
  }

  /// 設定播放模式
  void setMode(PlaybackMode mode) {
    final current = state;
    if (current == null) return;
    state = current.copyWith(mode: mode);
  }

  /// 循環切換播放模式：依序 -> 隨機 -> 單集 -> 依序
  void cycleMode() {
    final current = state;
    if (current == null) return;
    final next = switch (current.mode) {
      PlaybackMode.sequential => PlaybackMode.shuffle,
      PlaybackMode.shuffle => PlaybackMode.single,
      PlaybackMode.single => PlaybackMode.sequential,
    };
    state = current.copyWith(mode: next);
  }
}
