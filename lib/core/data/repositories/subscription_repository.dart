import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../db/subscription_database.dart';
import '../models/podcast.dart';

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  final database = ref.watch(subscriptionDatabaseProvider);
  final repository = SubscriptionRepository(database: database);
  ref.onDispose(repository.dispose);
  return repository;
}, name: 'subscriptionRepositoryProvider');

class SubscriptionRepository {
  SubscriptionRepository({required this.database}) {
    _loadFuture = _loadFromDatabase();
  }

  final SubscriptionDatabase database;
  final _subscriptions = <String, Podcast>{};
  final _listeners = <void Function(List<Podcast>)>[];
  late final Future<void> _loadFuture;

  List<Podcast> get current => _subscriptions.values.toList(growable: false);

  bool isSubscribed(String feedUrl) => _subscriptions.containsKey(feedUrl);

  Future<void> subscribe(Podcast podcast) async {
    await _loadFuture;
    _subscriptions[podcast.feedUrl] = podcast;
    final db = await database.database;
    await db.insert(
      'subscriptions',
      _toMap(podcast),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _notify();
  }

  Future<void> unsubscribe(String feedUrl) async {
    await _loadFuture;
    _subscriptions.remove(feedUrl);
    final db = await database.database;
    await db.delete(
      'subscriptions',
      where: 'feed_url = ?',
      whereArgs: [feedUrl],
    );
    _notify();
  }

  Future<void> clear() async {
    await _loadFuture;
    _subscriptions.clear();
    final db = await database.database;
    await db.delete('subscriptions');
    _notify();
  }

  void addListener(void Function(List<Podcast>) listener) {
    _listeners.add(listener);
    listener(current);
  }

  void removeListener(void Function(List<Podcast>) listener) {
    _listeners.remove(listener);
  }

  void dispose() {
    _listeners.clear();
    _subscriptions.clear();
  }

  Future<void> _loadFromDatabase() async {
    final db = await database.database;
    final rows = await db.query('subscriptions');
    for (final row in rows) {
      final podcast = _fromMap(row);
      _subscriptions[podcast.feedUrl] = podcast;
    }
    _notify();
  }

  void _notify() {
    final snapshot = current;
    for (final listener in _listeners) {
      listener(snapshot);
    }
  }

  Map<String, Object?> _toMap(Podcast podcast) {
    return {
      'feed_url': podcast.feedUrl,
      'id': podcast.id,
      'title': podcast.title,
      'author': podcast.author,
      'description': podcast.description,
      'artwork_url': podcast.artworkUrl,
    };
  }

  Podcast _fromMap(Map<String, Object?> map) {
    return Podcast(
      id: map['id'] as String? ?? map['feed_url'] as String,
      title: map['title'] as String? ?? '未知節目',
      author: map['author'] as String? ?? '',
      feedUrl: map['feed_url'] as String,
      description: map['description'] as String?,
      artworkUrl: map['artwork_url'] as String?,
      language: null,
      category: null,
      episodes: const [],
    );
  }
}
