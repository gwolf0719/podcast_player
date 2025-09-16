import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/audio_engine.dart';
import '../../../core/data/models/podcast.dart';
import '../../../core/data/models/podcast.dart' as models show Episode;
import 'playback_state.dart';

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
          break;
        case EngineProcessingState.idle:
          state = current.copyWith(isLoading: false, isPlaying: status.playing);
          break;
      }
    });

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
      final source = localFilePath != null
          ? Uri.file(localFilePath).toString()
          : episode.audioUrl;
      await _engine.setUrl(source);
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
      await _engine.play();
      state = current.copyWith(isPlaying: true);
    }
  }

  Future<void> stop() async {
    await _engine.stop();
    state = null;
  }

  void _cleanupSubscriptions() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _statusSub?.cancel();
  }
}
