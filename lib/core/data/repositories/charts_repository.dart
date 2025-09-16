import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sqflite/sqflite.dart';

import '../../db/charts_database.dart';
import '../../network/apple_podcasts_rss_client.dart';
import '../models/podcast.dart';

final chartsRepositoryProvider = Provider<ChartsRepository>((ref) {
  final rssClient = ref.watch(applePodcastsRssClientProvider);
  final database = ref.watch(chartsDatabaseProvider);
  return ChartsRepository(rssClient: rssClient, database: database);
}, name: 'chartsRepositoryProvider');

class ChartsRepository {
  ChartsRepository({
    required this.rssClient,
    required this.database,
    this.cacheDuration = const Duration(hours: 24),
    DateTime Function()? nowBuilder,
  }) : _nowBuilder = nowBuilder ?? DateTime.now {
    _loadFuture = _loadFromCache();
  }

  final ApplePodcastsRssClient rssClient;
  final ChartsDatabase database;
  final Duration cacheDuration;
  final DateTime Function() _nowBuilder;
  late final Future<void> _loadFuture;

  List<Podcast> _cache = const [];
  DateTime? _cacheTimestamp;

  Future<List<Podcast>> fetchTrendingTW({
    String? genreId,
    bool forceRefresh = false,
  }) async {
    await _loadFuture;
    final now = _nowBuilder();
    final cacheValid =
        _cache.isNotEmpty &&
        _cacheTimestamp != null &&
        now.difference(_cacheTimestamp!) < cacheDuration;

    if (!forceRefresh && cacheValid) {
      return _cache;
    }

    final podcasts = await rssClient.fetchTopPodcasts(genreId: genreId);
    await _saveCache(podcasts, now);
    _cache = podcasts;
    _cacheTimestamp = now;
    return podcasts;
  }

  Future<void> clearCache() async {
    final db = await database.database;
    await db.delete('charts');
    _cache = const [];
    _cacheTimestamp = null;
  }

  Future<void> _loadFromCache() async {
    final db = await database.database;
    final rows = await db.query('charts', orderBy: 'position ASC');
    if (rows.isEmpty) {
      _cache = const [];
      _cacheTimestamp = null;
      return;
    }

    _cache = rows.map(_fromMap).toList(growable: false);
    final updated = rows.first['updated_at'] as int?;
    if (updated != null) {
      _cacheTimestamp = DateTime.fromMillisecondsSinceEpoch(updated);
    }
  }

  Future<void> _saveCache(List<Podcast> podcasts, DateTime now) async {
    final db = await database.database;
    final batch = db.batch();
    batch.delete('charts');
    for (var i = 0; i < podcasts.length; i++) {
      batch.insert(
        'charts',
        _toMap(podcasts[i], i + 1, now),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Map<String, Object?> _toMap(Podcast podcast, int position, DateTime now) {
    return {
      'feed_url': podcast.feedUrl,
      'position': position,
      'podcast_id': podcast.id,
      'title': podcast.title,
      'author': podcast.author,
      'description': podcast.description,
      'artwork_url': podcast.artworkUrl,
      'category': podcast.category,
      'updated_at': now.millisecondsSinceEpoch,
    };
  }

  Podcast _fromMap(Map<String, Object?> map) {
    return Podcast(
      id: map['podcast_id'] as String? ?? map['feed_url'] as String,
      title: map['title'] as String? ?? '未知節目',
      author: map['author'] as String? ?? '',
      feedUrl: map['feed_url'] as String,
      description: map['description'] as String?,
      artworkUrl: map['artwork_url'] as String?,
      category: map['category'] as String?,
      language: null,
      episodes: const [],
    );
  }
}
