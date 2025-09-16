import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sqflite/sqflite.dart';

import '../../db/download_database.dart';
import '../models/download_task.dart';

final downloadRepositoryProvider = Provider<DownloadRepository>((ref) {
  final database = ref.watch(downloadDatabaseProvider);
  final repository = DownloadRepository(database: database);
  ref.onDispose(repository.dispose);
  return repository;
}, name: 'downloadRepositoryProvider');

class DownloadRepository {
  DownloadRepository({required this.database}) {
    _loadFromDatabase();
  }

  final DownloadDatabase database;
  final _tasks = <String, DownloadTask>{};
  final _listeners = <void Function(List<DownloadTask>)>[];
  bool _initialized = false;

  List<DownloadTask> get tasks => _tasks.values.toList(growable: false);

  bool hasTask(String episodeId) =>
      _tasks.values.any((task) => task.episodeId == episodeId);

  Future<DownloadTask> add(DownloadTask task) async {
    _tasks[task.id] = task;
    final db = await database.database;
    await db.insert(
      'downloads',
      task.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _notify();
    return task;
  }

  Future<void> update(
    String id,
    DownloadTask Function(DownloadTask) updater,
  ) async {
    final existing = _tasks[id];
    if (existing == null) {
      return;
    }
    final updated = updater(existing);
    _tasks[id] = updated;
    final db = await database.database;
    await db.update(
      'downloads',
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [id],
    );
    _notify();
  }

  Future<void> remove(String id) async {
    _tasks.remove(id);
    final db = await database.database;
    await db.delete('downloads', where: 'id = ?', whereArgs: [id]);
    _notify();
  }

  Future<void> clear() async {
    _tasks.clear();
    final db = await database.database;
    await db.delete('downloads');
    _notify();
  }

  void addListener(void Function(List<DownloadTask>) listener) {
    _listeners.add(listener);
    if (_initialized) {
      listener(tasks);
    }
  }

  void removeListener(void Function(List<DownloadTask>) listener) {
    _listeners.remove(listener);
  }

  void dispose() {
    _listeners.clear();
    _tasks.clear();
  }

  Future<void> _loadFromDatabase() async {
    final db = await database.database;
    final rows = await db.query('downloads', orderBy: 'created_at ASC');
    for (final row in rows) {
      final task = DownloadTask.fromMap(row);
      _tasks[task.id] = task;
    }
    _initialized = true;
    _notify();
  }

  void _notify() {
    if (!_initialized) {
      return;
    }
    final snapshot = tasks;
    for (final listener in _listeners) {
      listener(snapshot);
    }
  }
}
