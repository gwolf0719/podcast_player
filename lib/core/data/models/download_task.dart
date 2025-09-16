enum DownloadStatus { queued, downloading, completed, failed, canceled }

class DownloadTask {
  const DownloadTask({
    required this.id,
    required this.episodeId,
    required this.podcastTitle,
    required this.episodeTitle,
    required this.audioUrl,
    required this.status,
    required this.progress,
    required this.createdAt,
    this.errorMessage,
    this.filePath,
  });

  final String id;
  final String episodeId;
  final String podcastTitle;
  final String episodeTitle;
  final String audioUrl;
  final DownloadStatus status;
  final double progress; // 0.0 ~ 1.0
  final String? errorMessage;
  final String? filePath;
  final DateTime createdAt;

  DownloadTask copyWith({
    DownloadStatus? status,
    double? progress,
    Object? errorMessage = _noUpdate,
    Object? filePath = _noUpdate,
  }) {
    return DownloadTask(
      id: id,
      episodeId: episodeId,
      podcastTitle: podcastTitle,
      episodeTitle: episodeTitle,
      audioUrl: audioUrl,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      errorMessage: errorMessage == _noUpdate
          ? this.errorMessage
          : errorMessage as String?,
      filePath: filePath == _noUpdate ? this.filePath : filePath as String?,
      createdAt: createdAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'episode_id': episodeId,
      'podcast_title': podcastTitle,
      'episode_title': episodeTitle,
      'audio_url': audioUrl,
      'status': status.name,
      'progress': progress,
      'error_message': errorMessage,
      'file_path': filePath,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  static DownloadTask fromMap(Map<String, Object?> map) {
    return DownloadTask(
      id: map['id'] as String,
      episodeId: map['episode_id'] as String,
      podcastTitle: map['podcast_title'] as String,
      episodeTitle: map['episode_title'] as String,
      audioUrl: map['audio_url'] as String,
      status: DownloadStatus.values.firstWhere(
        (status) => status.name == map['status'],
      ),
      progress: (map['progress'] as num).toDouble(),
      errorMessage: map['error_message'] as String?,
      filePath: map['file_path'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['created_at'] as num).toInt(),
      ),
    );
  }
}

const _noUpdate = Object();
