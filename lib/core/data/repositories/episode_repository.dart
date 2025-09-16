import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../db/episode_database.dart';
import '../models/podcast.dart' as models show Episode;

final episodeRepositoryProvider = Provider<EpisodeRepository>((ref) {
  final database = ref.watch(episodeDatabaseProvider);
  return EpisodeRepository(database: database);
}, name: 'episodeRepositoryProvider');

class EpisodeRepository {
  EpisodeRepository({required this.database});

  final EpisodeDatabase database;

  Future<void> upsertEpisodes(String feedUrl, List<models.Episode> episodes) async {
    final db = await database.database;
    final batch = db.batch();
    for (final episode in episodes) {
      batch.insert(
        'episodes',
        _toMap(feedUrl, episode),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<models.Episode>> listEpisodes(String feedUrl) async {
    final db = await database.database;
    final rows = await db.query(
      'episodes',
      where: 'podcast_feed_url = ?',
      whereArgs: [feedUrl],
      orderBy: 'published_at DESC',
    );
    return rows.map(_fromMap).toList(growable: false);
  }

  Future<models.Episode?> findEpisode(String episodeId) async {
    final db = await database.database;
    final rows = await db.query(
      'episodes',
      where: 'episode_id = ?',
      whereArgs: [episodeId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return _fromMap(rows.first);
  }

  Map<String, Object?> _toMap(String feedUrl, models.Episode episode) {
    return {
      'podcast_feed_url': feedUrl,
      'episode_id': episode.id,
      'title': episode.title,
      'description': episode.description,
      'audio_url': episode.audioUrl,
      'published_at': episode.publishedAt?.millisecondsSinceEpoch,
      'duration_seconds': episode.duration?.inSeconds,
      'image_url': episode.imageUrl,
    };
  }

  models.Episode _fromMap(Map<String, Object?> map) {
    return models.Episode(
      id: map['episode_id'] as String,
      title: map['title'] as String? ?? '未知單集',
      audioUrl: map['audio_url'] as String? ?? '',
      description: map['description'] as String?,
      publishedAt: map['published_at'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              (map['published_at'] as num).toInt(),
            ),
      duration: map['duration_seconds'] == null
          ? null
          : Duration(seconds: (map['duration_seconds'] as num).toInt()),
      imageUrl: map['image_url'] as String?,
      podcastFeedUrl: map['podcast_feed_url'] as String?,
    );
  }
}
