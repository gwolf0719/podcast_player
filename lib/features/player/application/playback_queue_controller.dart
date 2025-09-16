import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/models/podcast.dart';
import '../../../core/data/models/podcast.dart' as models show Episode;

/// 播放隊列狀態
class PlaybackQueue {
  const PlaybackQueue({
    required this.episodes,
    this.currentIndex = -1,
  });

  final List<QueueEpisode> episodes;
  final int currentIndex;

  bool get isEmpty => episodes.isEmpty;
  bool get isNotEmpty => episodes.isNotEmpty;
  int get length => episodes.length;

  QueueEpisode? get currentEpisode {
    if (currentIndex >= 0 && currentIndex < episodes.length) {
      return episodes[currentIndex];
    }
    return null;
  }

  bool get hasNext => currentIndex < episodes.length - 1;
  bool get hasPrevious => currentIndex > 0;

  PlaybackQueue copyWith({
    List<QueueEpisode>? episodes,
    int? currentIndex,
  }) {
    return PlaybackQueue(
      episodes: episodes ?? this.episodes,
      currentIndex: currentIndex ?? this.currentIndex,
    );
  }

  /// 檢查節目是否已在隊列中
  bool isInQueue(models.Episode episode) {
    return episodes.any((queueEpisode) => 
        queueEpisode.episode.id == episode.id);
  }

  /// 獲取節目在隊列中的位置
  int getEpisodeIndex(models.Episode episode) {
    return episodes.indexWhere((queueEpisode) => 
        queueEpisode.episode.id == episode.id);
  }
}

/// 隊列中的節目資訊
class QueueEpisode {
  const QueueEpisode({
    required this.episode,
    required this.podcast,
    this.localFilePath,
  });

  final models.Episode episode;
  final Podcast podcast;
  final String? localFilePath;
}

/// 播放隊列控制器
final playbackQueueControllerProvider =
    NotifierProvider<PlaybackQueueController, PlaybackQueue>(
      PlaybackQueueController.new,
      name: 'playbackQueueControllerProvider',
    );

class PlaybackQueueController extends Notifier<PlaybackQueue> {
  @override
  PlaybackQueue build() {
    return const PlaybackQueue(episodes: []);
  }

  /// 添加節目到隊列末尾
  void addToQueue(Podcast podcast, models.Episode episode, {String? localFilePath}) {
    final queueEpisode = QueueEpisode(
      episode: episode,
      podcast: podcast,
      localFilePath: localFilePath,
    );

    final updatedEpisodes = [...state.episodes, queueEpisode];
    state = state.copyWith(episodes: updatedEpisodes);
  }

  /// 添加多個節目到隊列
  void addAllToQueue(List<QueueEpisode> episodes) {
    final updatedEpisodes = [...state.episodes, ...episodes];
    state = state.copyWith(episodes: updatedEpisodes);
  }

  /// 插入節目到隊列指定位置（下一首播放）
  void playNext(Podcast podcast, models.Episode episode, {String? localFilePath}) {
    final queueEpisode = QueueEpisode(
      episode: episode,
      podcast: podcast,
      localFilePath: localFilePath,
    );

    final insertIndex = state.currentIndex + 1;
    final updatedEpisodes = [...state.episodes];
    updatedEpisodes.insert(insertIndex, queueEpisode);
    
    state = state.copyWith(episodes: updatedEpisodes);
  }

  /// 立即播放節目（替換當前播放並清空隊列）
  void playNow(Podcast podcast, models.Episode episode, {String? localFilePath}) {
    final queueEpisode = QueueEpisode(
      episode: episode,
      podcast: podcast,
      localFilePath: localFilePath,
    );

    state = PlaybackQueue(
      episodes: [queueEpisode],
      currentIndex: 0,
    );
  }

  /// 設置當前播放索引
  void setCurrentIndex(int index) {
    if (index >= 0 && index < state.episodes.length) {
      state = state.copyWith(currentIndex: index);
    }
  }

  /// 移動到下一首
  QueueEpisode? moveToNext() {
    if (state.hasNext) {
      final nextIndex = state.currentIndex + 1;
      state = state.copyWith(currentIndex: nextIndex);
      return state.currentEpisode;
    }
    return null;
  }

  /// 移動到上一首
  QueueEpisode? moveToPrevious() {
    if (state.hasPrevious) {
      final prevIndex = state.currentIndex - 1;
      state = state.copyWith(currentIndex: prevIndex);
      return state.currentEpisode;
    }
    return null;
  }

  /// 從隊列中移除節目
  void removeFromQueue(int index) {
    if (index >= 0 && index < state.episodes.length) {
      final updatedEpisodes = [...state.episodes];
      updatedEpisodes.removeAt(index);
      
      int newCurrentIndex = state.currentIndex;
      if (index < state.currentIndex) {
        newCurrentIndex = state.currentIndex - 1;
      } else if (index == state.currentIndex) {
        newCurrentIndex = -1; // 當前播放的被移除，重置索引
      }
      
      state = state.copyWith(
        episodes: updatedEpisodes,
        currentIndex: newCurrentIndex,
      );
    }
  }

  /// 清空隊列
  void clearQueue() {
    state = const PlaybackQueue(episodes: []);
  }

  /// 重新排序隊列
  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= state.episodes.length ||
        newIndex < 0 || newIndex >= state.episodes.length) {
      return;
    }

    final updatedEpisodes = [...state.episodes];
    final episode = updatedEpisodes.removeAt(oldIndex);
    updatedEpisodes.insert(newIndex, episode);

    // 調整當前播放索引
    int newCurrentIndex = state.currentIndex;
    if (oldIndex == state.currentIndex) {
      newCurrentIndex = newIndex;
    } else if (oldIndex < state.currentIndex && newIndex >= state.currentIndex) {
      newCurrentIndex = state.currentIndex - 1;
    } else if (oldIndex > state.currentIndex && newIndex <= state.currentIndex) {
      newCurrentIndex = state.currentIndex + 1;
    }

    state = state.copyWith(
      episodes: updatedEpisodes,
      currentIndex: newCurrentIndex,
    );
  }

}
