import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:podcast_player/core/data/models/podcast.dart' as models show Episode;
import 'package:podcast_player/core/data/repositories/episode_repository.dart';
import 'package:podcast_player/core/db/episode_database.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('EpisodeRepository', () {
    late Directory tempDir;
    late EpisodeRepository repository;
    late EpisodeDatabase database;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('episode_repo');
      database = EpisodeDatabase(
        overridePath: p.join(tempDir.path, 'episodes.db'),
      );
      repository = EpisodeRepository(database: database);
    });

    tearDown(() async {
      await database.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('upsert 與查詢單集', () async {
      final episodes = [
        const models.Episode(
          id: 'ep1',
          title: 'Episode One',
          audioUrl: 'https://example.com/audio1.mp3',
        ),
      ];

      await repository.upsertEpisodes('https://feed', episodes);

      final stored = await repository.listEpisodes('https://feed');
      expect(stored, hasLength(1));
      expect(stored.first.id, 'ep1');

      final single = await repository.findEpisode('ep1');
      expect(single, isNotNull);
      expect(single!.title, 'Episode One');
    });
  });
}
