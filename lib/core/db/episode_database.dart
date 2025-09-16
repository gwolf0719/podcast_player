import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

final episodeDatabaseProvider = Provider<EpisodeDatabase>((ref) {
  final database = EpisodeDatabase();
  ref.onDispose(() => database.close());
  return database;
}, name: 'episodeDatabaseProvider');

class EpisodeDatabase {
  EpisodeDatabase({this.overridePath});

  final String? overridePath;
  Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    final dbPath = overridePath ?? await _defaultPath();
    _database = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
CREATE TABLE episodes (
  podcast_feed_url TEXT,
  episode_id TEXT,
  title TEXT,
  description TEXT,
  audio_url TEXT,
  published_at INTEGER,
  duration_seconds INTEGER,
  image_url TEXT,
  PRIMARY KEY (podcast_feed_url, episode_id)
)
''');
      },
    );

    return _database!;
  }

  Future<String> _defaultPath() async {
    final directory = await getApplicationDocumentsDirectory();
    await Directory(directory.path).create(recursive: true);
    return p.join(directory.path, 'episodes.db');
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
