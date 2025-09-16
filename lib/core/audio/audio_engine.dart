import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

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

  Future<void> setUrl(String url);
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
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
  Future<void> setUrl(String url) async {
    await _player.setUrl(url);
  }

  @override
  Future<void> stop() => _player.stop();

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
