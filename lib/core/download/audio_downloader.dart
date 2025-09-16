import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final audioDownloaderProvider = Provider<AudioDownloader>((ref) {
  final downloader = DioAudioDownloader();
  ref.onDispose(downloader.dispose);
  return downloader;
}, name: 'audioDownloaderProvider');

abstract class AudioDownloader {
  Future<void> download({
    required String url,
    required String savePath,
    required void Function(int received, int total) onReceiveProgress,
    required CancelToken cancelToken,
  });

  Future<bool> exists(String path);
}

class DioAudioDownloader implements AudioDownloader {
  DioAudioDownloader() : _dio = Dio();

  final Dio _dio;

  @override
  Future<void> download({
    required String url,
    required String savePath,
    required void Function(int received, int total) onReceiveProgress,
    required CancelToken cancelToken,
  }) async {
    await _dio.download(
      url,
      savePath,
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress,
      options: Options(responseType: ResponseType.bytes, followRedirects: true),
    );
  }

  @override
  Future<bool> exists(String path) async {
    return File(path).exists();
  }

  void dispose() {
    _dio.close(force: true);
  }
}
