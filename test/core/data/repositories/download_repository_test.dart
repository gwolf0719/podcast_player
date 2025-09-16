import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:podcast_player/core/data/models/download_task.dart';
import 'package:podcast_player/core/data/repositories/download_repository.dart';
import 'package:podcast_player/core/db/download_database.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late DownloadRepository repository;
  late DownloadDatabase database;
  late String dbPath;

  setUp(() async {
    final tempDir = await Directory.systemTemp.createTemp('repo_db');
    dbPath = p.join(tempDir.path, 'repo_test.db');
    database = DownloadDatabase(overridePath: dbPath);
    repository = DownloadRepository(database: database);
    await Future<void>.delayed(const Duration(milliseconds: 10));
  });

  tearDown(() async {
    await database.close();
    final file = File(dbPath);
    if (await file.exists()) {
      await file.parent.delete(recursive: true);
    }
  });

  test('add/update/remove task persists to database', () async {
    final task = DownloadTask(
      id: 'task-1',
      episodeId: 'episode-1',
      podcastTitle: 'Swift Talk',
      episodeTitle: 'Episode 1',
      audioUrl: 'https://example.com/audio.mp3',
      status: DownloadStatus.queued,
      progress: 0,
      createdAt: DateTime.now(),
    );

    await repository.add(task);
    expect(repository.tasks, hasLength(1));

    await repository.update(task.id, (current) {
      return current.copyWith(status: DownloadStatus.completed, progress: 1);
    });
    expect(repository.tasks.first.status, DownloadStatus.completed);

    await repository.remove(task.id);
    expect(repository.tasks, isEmpty);
  });
}
