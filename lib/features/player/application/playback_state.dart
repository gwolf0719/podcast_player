/// 這個檔案負責：
/// - 定義播放狀態（PlaybackState）資料結構
/// - 提供拷貝（copyWith）以便控制器更新局部欄位
/// - 定義播放模式（依序/隨機/單集）以控制自動播放行為
import '../../../core/data/models/podcast.dart';
import '../../../core/data/models/podcast.dart' as models show Episode;

/// 播放模式
/// - sequential：依序播放隊列中下一首
/// - shuffle：隨機從隊列中挑選下一首（不重複當前）
/// - single：只播放當前單集，結束後停止
enum PlaybackMode { sequential, shuffle, single }

class PlaybackState {
  const PlaybackState({
    required this.podcast,
    required this.episode,
    required this.isLoading,
    required this.isPlaying,
    required this.position,
    required this.duration,
    this.mode = PlaybackMode.sequential,
    this.errorMessage,
  });

  final Podcast podcast;
  final models.Episode episode;
  final bool isLoading;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final PlaybackMode mode;
  final String? errorMessage;

  PlaybackState copyWith({
    bool? isLoading,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    PlaybackMode? mode,
    Object? errorMessage = _noUpdate,
  }) {
    return PlaybackState(
      podcast: podcast,
      episode: episode,
      isLoading: isLoading ?? this.isLoading,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      mode: mode ?? this.mode,
      errorMessage: errorMessage == _noUpdate
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

const _noUpdate = Object();
