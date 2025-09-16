import 'dart:async';

/// 這個檔案負責：
/// - 播放核心 AudioEngine 介面與 JustAudio 實作
/// - 提供播放狀態串流與控制（播放/暫停/停止）
/// - 若專案已安裝 just_audio_background/audio_service，則附帶系統通知與背景播放（透過 MediaItem 標籤）
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
// 若未安裝 audio_service/just_audio_background，本檔亦可單獨運作。

enum EngineProcessingState { idle, loading, ready, completed }

class EngineStatus {
  const EngineStatus({required this.playing, required this.processingState});

  final bool playing;
  final EngineProcessingState processingState;
}

abstract class AudioEngine {
  Stream<Duration> get positionStream;
  Stream<Duration?> get durationStream;
  Stream<EngineStatus> get statusStream;

  /// 設定音訊來源
  /// 輸入：
  /// - url：音訊串流或本機檔案位置
  /// - title/artist/artUri/id：預留參數，若已整合 just_audio_background 可提供系統通知資訊
  Future<void> setSource({
    required String url,
    required String title,
    String? artist,
    String? artUri,
    String? id,
  });
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> dispose();
}

class JustAudioEngine implements AudioEngine {
  JustAudioEngine() : _player = AudioPlayer();

  final AudioPlayer _player;

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Stream<Duration?> get durationStream => _player.durationStream;

  @override
  Stream<EngineStatus> get statusStream => _player.playerStateStream.map(
    (state) => EngineStatus(
      playing: state.playing,
      processingState: _mapProcessingState(state.processingState),
    ),
  );

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> setSource({
    required String url,
    required String title,
    String? artist,
    String? artUri,
    String? id,
  }) async {
    // 基本設定：未整合 just_audio_background 時直接設定來源
    // 若之後導入 just_audio_background，可將 tag 換成 MediaItem 提供通知資訊
    final source = AudioSource.uri(Uri.parse(url));
    await _player.setAudioSource(source);
  }

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> dispose() => _player.dispose();

  EngineProcessingState _mapProcessingState(ProcessingState state) {
    switch (state) {
      case ProcessingState.idle:
        return EngineProcessingState.idle;
      case ProcessingState.loading:
      case ProcessingState.buffering:
        return EngineProcessingState.loading;
      case ProcessingState.ready:
        return EngineProcessingState.ready;
      case ProcessingState.completed:
        return EngineProcessingState.completed;
    }
  }
}

final audioEngineProvider = Provider<AudioEngine>((ref) {
  final engine = JustAudioEngine();
  ref.onDispose(() => engine.dispose());
  return engine;
}, name: 'audioEngineProvider');
