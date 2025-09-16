import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

final chartsDatabaseProvider = Provider<ChartsDatabase>((ref) {
  final database = ChartsDatabase();
  ref.onDispose(() => database.close());
  return database;
}, name: 'chartsDatabaseProvider');

class ChartsDatabase {
  ChartsDatabase({this.overridePath});

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
CREATE TABLE charts (
  feed_url TEXT PRIMARY KEY,
  position INTEGER,
  podcast_id TEXT,
  title TEXT,
  author TEXT,
  description TEXT,
  artwork_url TEXT,
  category TEXT,
  updated_at INTEGER
)
''');
      },
    );

    return _database!;
  }

  Future<String> _defaultPath() async {
    final directory = await getApplicationDocumentsDirectory();
    await Directory(directory.path).create(recursive: true);
    return p.join(directory.path, 'charts_cache.db');
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
