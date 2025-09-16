import '../../../core/data/models/podcast.dart';
import '../../../core/data/models/podcast.dart' as models show Episode;

class PlaybackState {
  const PlaybackState({
    required this.podcast,
    required this.episode,
    required this.isLoading,
    required this.isPlaying,
    required this.position,
    required this.duration,
    this.errorMessage,
  });

  final Podcast podcast;
  final models.Episode episode;
  final bool isLoading;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final String? errorMessage;

  PlaybackState copyWith({
    bool? isLoading,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    Object? errorMessage = _noUpdate,
  }) {
    return PlaybackState(
      podcast: podcast,
      episode: episode,
      isLoading: isLoading ?? this.isLoading,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      errorMessage: errorMessage == _noUpdate
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

const _noUpdate = Object();
