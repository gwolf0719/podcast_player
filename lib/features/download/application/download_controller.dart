import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:dio/dio.dart';

import '../../../core/data/models/download_task.dart';
import '../../../core/data/models/podcast.dart';
import '../../../core/data/models/podcast.dart' as models show Episode;
import '../../../core/data/models/user_settings.dart';
import '../../../core/data/repositories/download_repository.dart';
import '../../../core/data/repositories/settings_repository.dart';
import '../../../core/download/audio_downloader.dart';
import '../../../core/network/network_status.dart';

final downloadControllerProvider =
    StateNotifierProvider<DownloadController, List<DownloadTask>>((ref) {
      final repository = ref.watch(downloadRepositoryProvider);
      final downloader = ref.watch(audioDownloaderProvider);
      final settingsRepository = ref.watch(settingsRepositoryProvider);
      final networkStatus = ref.watch(networkStatusProvider);
      return DownloadController(
        repository: repository,
        downloader: downloader,
        settingsRepository: settingsRepository,
        networkStatus: networkStatus,
      );
    }, name: 'downloadControllerProvider');

class DownloadController extends StateNotifier<List<DownloadTask>> {
  DownloadController({
    required DownloadRepository repository,
    required AudioDownloader downloader,
    required SettingsRepository settingsRepository,
    required NetworkStatus networkStatus,
    this.maxConcurrent = 2,
  }) : _repository = repository,
       _downloader = downloader,
       _settingsRepository = settingsRepository,
       _networkStatus = networkStatus,
       super(repository.tasks) {
    _repository.addListener(_onRepositoryChanged);
    _settings = UserSettings.defaults;
    _settingsRepository.load().then((value) {
      _settings = value;
      _enforceStorageLimit();
      purgeExpiredDownloads();
    });
    _settingsSubscription = _settingsRepository.stream.listen((settings) {
      _settings = settings;
      _enforceStorageLimit();
      purgeExpiredDownloads();
      _processQueue();
    });
  }

  final DownloadRepository _repository;
  final AudioDownloader _downloader;
  final SettingsRepository _settingsRepository;
  final NetworkStatus _networkStatus;
  final int maxConcurrent;
  final _queue = Queue<String>();
  final _cancelTokens = <String, CancelToken>{};
  final _uuid = const Uuid();
  UserSettings _settings = UserSettings.defaults;
  StreamSubscription<UserSettings>? _settingsSubscription;

  void _onRepositoryChanged(List<DownloadTask> tasks) {
    state = tasks;
    _processQueue();
  }

  Future<void> startDownload(Podcast podcast, models.Episode episode) async {
    if (_repository.hasTask(episode.id)) {
      return;
    }

    final id = _uuid.v4();
    final task = DownloadTask(
      id: id,
      episodeId: episode.id,
      podcastTitle: podcast.title,
      episodeTitle: episode.title,
      audioUrl: episode.audioUrl,
      status: DownloadStatus.queued,
      progress: 0,
      createdAt: DateTime.now(),
      isProtected: false,
      completedAt: null,
    );

    await _repository.add(task);
    if (!_queue.contains(id)) {
      _queue.add(id);
    }
    _processQueue();
  }

  Future<void> cancelDownload(String taskId) async {
    final token = _cancelTokens.remove(taskId);
    token?.cancel('使用者取消');
    await _repository.update(taskId, (task) {
      return task.copyWith(
        status: DownloadStatus.canceled,
        progress: 0,
        errorMessage: null,
        completedAt: null,
      );
    });
    _queue.remove(taskId);
    _processQueue();
  }

  Future<void> removeTask(String taskId) async {
    final token = _cancelTokens.remove(taskId);
    token?.cancel('移除下載');
    DownloadTask? task;
    for (final element in state) {
      if (element.id == taskId) {
        task = element;
        break;
      }
    }
    if (task?.filePath != null) {
      final file = File(task!.filePath!);
      if (await file.exists()) {
        await file.delete();
      }
    }
    await _repository.remove(taskId);
    _queue.remove(taskId);
    _processQueue();
  }

  Future<void> retry(String taskId) async {
    await _repository.update(taskId, (task) {
      return task.copyWith(
        status: DownloadStatus.queued,
        progress: 0,
        errorMessage: null,
        completedAt: null,
      );
    });
    if (!_queue.contains(taskId)) {
      _queue.add(taskId);
    }
    _processQueue();
  }

  Future<void> pauseDownload(String taskId) async {
    final token = _cancelTokens.remove(taskId);
    token?.cancel('使用者暫停');
    await _repository.update(taskId, (task) {
      return task.copyWith(
        status: DownloadStatus.paused,
        errorMessage: null,
      );
    });
    _queue.remove(taskId);
    _processQueue();
  }

  Future<void> resumeDownload(String taskId) async {
    await _repository.update(taskId, (task) {
      return task.copyWith(
        status: DownloadStatus.queued,
        errorMessage: null,
        completedAt: null,
      );
    });
    if (!_queue.contains(taskId)) {
      _queue.add(taskId);
    }
    _processQueue();
  }

  void _processQueue() {
    var active = _cancelTokens.length;
    while (_queue.isNotEmpty && active < maxConcurrent) {
      final nextId = _queue.removeFirst();
      _startDownload(nextId);
      active += 1;
    }
  }

  Future<void> _startDownload(String taskId) async {
    DownloadTask? lookup;
    for (final element in state) {
      if (element.id == taskId) {
        lookup = element;
        break;
      }
    }
    final task = lookup;
    if (task == null || task.status == DownloadStatus.downloading) {
      return;
    }

    if (_settings.wifiOnly) {
      final onWifi = await _networkStatus.isOnWifi();
      if (!onWifi) {
        if (!_queue.contains(taskId)) {
          _queue.add(taskId);
        }
        await _repository.update(task.id, (current) {
          return current.copyWith(
            status: DownloadStatus.queued,
            progress: 0,
            errorMessage: '等待 Wi-Fi 連線後再下載',
          );
        });
        return;
      }
    }

    final downloadDir = await _resolveDownloadDirectory();
    final filePath = p.join(downloadDir.path, '${task.episodeId}.mp3');
    final cancelToken = CancelToken();
    _cancelTokens[task.id] = cancelToken;

    await _repository.update(task.id, (current) {
      return current.copyWith(
        status: DownloadStatus.downloading,
        progress: 0.01,
        filePath: filePath,
        errorMessage: null,
        completedAt: null,
      );
    });

    try {
      await _downloader.download(
        url: task.audioUrl,
        savePath: filePath,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (total <= 0) {
            return;
          }
          final progress = (received / total).clamp(0.0, 1.0);
          _repository.update(task.id, (current) {
            return current.copyWith(progress: progress);
          });
        },
      );

      await _repository.update(task.id, (current) {
        return current.copyWith(
          status: DownloadStatus.completed,
          progress: 1.0,
          filePath: filePath,
          completedAt: DateTime.now(),
        );
      });
      await _enforceStorageLimit();
      await purgeExpiredDownloads();
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) {
        await _repository.update(task.id, (current) {
          return current.copyWith(
            status: DownloadStatus.canceled,
            errorMessage: '已取消',
            completedAt: null,
          );
        });
      } else {
        await _repository.update(task.id, (current) {
          return current.copyWith(
            status: DownloadStatus.failed,
            errorMessage: error.message ?? '下載失敗',
            completedAt: null,
          );
        });
      }
    } catch (error) {
      await _repository.update(task.id, (current) {
        return current.copyWith(
          status: DownloadStatus.failed,
          errorMessage: error.toString(),
          completedAt: null,
        );
      });
    } finally {
      _cancelTokens.remove(task.id);
      _processQueue();
    }
  }

  @override
  void dispose() {
    for (final token in _cancelTokens.values) {
      token.cancel('dispose');
    }
    _cancelTokens.clear();
    _repository.removeListener(_onRepositoryChanged);
    _settingsSubscription?.cancel();
    super.dispose();
  }

  Future<Directory> _resolveDownloadDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    final downloadDir = Directory(p.join(directory.path, 'audio_downloads'));
    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
    }
    return downloadDir;
  }

  Future<void> _enforceStorageLimit() async {
    final limitBytes = (_settings.storageLimitGb * 1024 * 1024 * 1024).round();
    if (limitBytes <= 0) {
      return;
    }

    final downloadDir = await _resolveDownloadDirectory();
    if (!await downloadDir.exists()) {
      return;
    }

    final files = <_FileEntry>[];
    var total = 0;
    await for (final entity in downloadDir.list()) {
      if (entity is! File) {
        continue;
      }
      final stat = await entity.stat();
      total += stat.size;
      files.add(
        _FileEntry(
          path: entity.path,
          size: stat.size,
          modified: stat.modified,
        ),
      );
    }

    if (total <= limitBytes) {
      return;
    }

    files.sort((a, b) => a.modified.compareTo(b.modified));
    final completed = {
      for (final task in state)
        if (task.status == DownloadStatus.completed &&
            task.filePath != null &&
            !task.isProtected)
          task.filePath!: task.id,
    };

    for (final entry in files) {
      if (total <= limitBytes) {
        break;
      }
      final file = File(entry.path);
      if (await file.exists()) {
        await file.delete();
      }
      total -= entry.size;
      final taskId = completed[entry.path];
      if (taskId != null) {
        await _repository.update(taskId, (current) {
          return current.copyWith(
            status: DownloadStatus.canceled,
            progress: 0,
            errorMessage: '超過容量限制，自動清除',
            filePath: null,
            completedAt: null,
          );
        });
      }
    }
  }

  /// 根據使用者設定自動排入最新集數的下載任務。
  Future<void> applyAutoDownloadRules(
    Podcast podcast,
    List<models.Episode> episodes,
  ) async {
    final limit = _settings.autoDownloadCount;
    if (limit <= 0) {
      return;
    }

    final sorted = [...episodes];
    sorted.sort((a, b) {
      final aTime = a.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });

    var added = 0;
    for (final episode in sorted) {
      if (added >= limit) {
        break;
      }
      final alreadyQueued = state.any((task) => task.episodeId == episode.id);
      if (alreadyQueued || _repository.hasTask(episode.id)) {
        continue;
      }
      await startDownload(podcast, episode);
      added += 1;
    }
  }

  Future<void> toggleProtection(String taskId) async {
    await _repository.update(taskId, (task) {
      return task.copyWith(isProtected: !task.isProtected);
    });
    await performMaintenance();
  }

  Future<void> purgeExpiredDownloads() async {
    final days = _settings.retentionDays;
    if (days <= 0) {
      return;
    }
    final cutoff = DateTime.now().subtract(Duration(days: days));
    for (final task in List<DownloadTask>.from(state)) {
      if (task.status != DownloadStatus.completed || task.isProtected) {
        continue;
      }
      final filePath = task.filePath;
      if (filePath == null) {
        continue;
      }
      final file = File(filePath);
      if (!await file.exists()) {
        continue;
      }
      final stat = await file.stat();
      final reference = task.completedAt ?? stat.modified;
      if (reference.isBefore(cutoff)) {
        await file.delete();
        await _repository.update(task.id, (current) {
          return current.copyWith(
            status: DownloadStatus.canceled,
            progress: 0,
            errorMessage: '超過保存期限，自動清除',
            filePath: null,
            completedAt: null,
          );
        });
      }
    }
  }

  /// 執行容量清理與保留期限檢查的整體維護流程。
  Future<void> performMaintenance() async {
    await _enforceStorageLimit();
    await purgeExpiredDownloads();
  }
}

class _FileEntry {
  const _FileEntry({required this.path, required this.size, required this.modified});

  final String path;
  final int size;
  final DateTime modified;
}
