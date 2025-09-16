import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:podcast_player/core/audio/audio_engine.dart';
import 'package:podcast_player/core/data/models/podcast.dart';
import 'package:podcast_player/core/data/models/podcast.dart'
    as models
    show Episode;
import 'package:podcast_player/features/player/application/audio_player_controller.dart';

class FakeAudioEngine implements AudioEngine {
  final positionController = StreamController<Duration>.broadcast();
  final durationController = StreamController<Duration?>.broadcast();
  final statusController = StreamController<EngineStatus>.broadcast();

  bool setUrlCalled = false;
  bool playCalled = false;
  bool pauseCalled = false;
  bool stopCalled = false;

  @override
  Stream<Duration> get positionStream => positionController.stream;

  @override
  Stream<Duration?> get durationStream => durationController.stream;

  @override
  Stream<EngineStatus> get statusStream => statusController.stream;

  @override
  Future<void> dispose() async {
    await positionController.close();
    await durationController.close();
    await statusController.close();
  }

  @override
  Future<void> pause() async {
    pauseCalled = true;
    statusController.add(
      const EngineStatus(
        playing: false,
        processingState: EngineProcessingState.ready,
      ),
    );
  }

  @override
  Future<void> play() async {
    playCalled = true;
    statusController.add(
      const EngineStatus(
        playing: true,
        processingState: EngineProcessingState.ready,
      ),
    );
  }

  @override
  Future<void> setUrl(String url) async {
    setUrlCalled = true;
    statusController.add(
      const EngineStatus(
        playing: false,
        processingState: EngineProcessingState.loading,
      ),
    );
  }

  @override
  Future<void> stop() async {
    stopCalled = true;
    statusController.add(
      const EngineStatus(
        playing: false,
        processingState: EngineProcessingState.idle,
      ),
    );
  }
}

void main() {
  test('playEpisode 更新狀態並可暫停/播放', () async {
    final engine = FakeAudioEngine();
    final container = ProviderContainer(
      overrides: [audioEngineProvider.overrideWithValue(engine)],
    );
    addTearDown(() async {
      await engine.dispose();
      container.dispose();
    });

    final controller = container.read(audioPlayerControllerProvider.notifier);
    final podcast = const Podcast(
      id: 'p1',
      title: '測試節目',
      author: '作者',
      feedUrl: 'https://example.com/feed',
      episodes: [],
    );
    const episode = models.Episode(
      id: 'e1',
      title: '第 1 集',
      audioUrl: 'https://example.com/audio.mp3',
    );

    await controller.playEpisode(podcast, episode);

    expect(engine.setUrlCalled, isTrue);
    expect(engine.playCalled, isTrue);

    engine.durationController.add(const Duration(minutes: 1));
    engine.positionController.add(const Duration(seconds: 10));
    await Future<void>.delayed(const Duration(milliseconds: 10));

    final state = container.read(audioPlayerControllerProvider);
    expect(state, isNotNull);
    expect(state!.episode.id, 'e1');
    expect(state.isPlaying, isTrue);

    await controller.togglePlayPause();
    expect(engine.pauseCalled, isTrue);

    await controller.togglePlayPause();
    expect(engine.playCalled, isTrue);

    await controller.stop();
    expect(engine.stopCalled, isTrue);
    expect(container.read(audioPlayerControllerProvider), isNull);
  });
}
