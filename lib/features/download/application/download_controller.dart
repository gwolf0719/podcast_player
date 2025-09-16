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
import '../../../core/data/repositories/download_repository.dart';
import '../../../core/download/audio_downloader.dart';

final downloadControllerProvider =
    StateNotifierProvider<DownloadController, List<DownloadTask>>((ref) {
      final repository = ref.watch(downloadRepositoryProvider);
      final downloader = ref.watch(audioDownloaderProvider);
      return DownloadController(repository: repository, downloader: downloader);
    }, name: 'downloadControllerProvider');

class DownloadController extends StateNotifier<List<DownloadTask>> {
  DownloadController({
    required DownloadRepository repository,
    required AudioDownloader downloader,
    this.maxConcurrent = 2,
  }) : _repository = repository,
       _downloader = downloader,
       super(repository.tasks) {
    _repository.addListener(_onRepositoryChanged);
  }

  final DownloadRepository _repository;
  final AudioDownloader _downloader;
  final int maxConcurrent;
  final _queue = Queue<String>();
  final _cancelTokens = <String, CancelToken>{};
  final _uuid = const Uuid();

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

    final directory = await getApplicationDocumentsDirectory();
    final downloadDir = Directory(p.join(directory.path, 'audio_downloads'));
    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
    }

    final filePath = p.join(downloadDir.path, '${task.episodeId}.mp3');
    final cancelToken = CancelToken();
    _cancelTokens[task.id] = cancelToken;

    await _repository.update(task.id, (current) {
      return current.copyWith(
        status: DownloadStatus.downloading,
        progress: 0.01,
        filePath: filePath,
        errorMessage: null,
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
        );
      });
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) {
        await _repository.update(task.id, (current) {
          return current.copyWith(
            status: DownloadStatus.canceled,
            errorMessage: '已取消',
          );
        });
      } else {
        await _repository.update(task.id, (current) {
          return current.copyWith(
            status: DownloadStatus.failed,
            errorMessage: error.message ?? '下載失敗',
          );
        });
      }
    } catch (error) {
      await _repository.update(task.id, (current) {
        return current.copyWith(
          status: DownloadStatus.failed,
          errorMessage: error.toString(),
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
    super.dispose();
  }
}
