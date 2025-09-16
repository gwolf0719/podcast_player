import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

final downloadDatabaseProvider = Provider<DownloadDatabase>((ref) {
  final database = DownloadDatabase();
  ref.onDispose(() => database.close());
  return database;
}, name: 'downloadDatabaseProvider');

class DownloadDatabase {
  DownloadDatabase({this.overridePath});

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
CREATE TABLE downloads (
  id TEXT PRIMARY KEY,
  episode_id TEXT,
  podcast_title TEXT,
  episode_title TEXT,
  audio_url TEXT,
  status TEXT,
  progress REAL,
  error_message TEXT,
  file_path TEXT,
  created_at INTEGER
)
''');
      },
    );

    return _database!;
  }

  Future<String> _defaultPath() async {
    final directory = await getApplicationDocumentsDirectory();
    await Directory(directory.path).create(recursive: true);
    return p.join(directory.path, 'downloads.db');
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
