import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../data/models/podcast.dart';
import '../data/models/search_results.dart';
import 'http_client_provider.dart';

class ApplePodcastsSearchException implements Exception {
  ApplePodcastsSearchException(this.message, [this.statusCode]);

  final String message;
  final int? statusCode;

  @override
  String toString() =>
      'ApplePodcastsSearchException(statusCode: $statusCode, message: $message)';
}

class ApplePodcastsSearchClient {
  ApplePodcastsSearchClient({
    required this.httpClient,
    this.countryCode = 'tw',
    this.language = 'zh_tw',
    this.resultLimit = 25,
  });

  final http.Client httpClient;
  final String countryCode;
  final String language;
  final int resultLimit;

  static const _host = 'itunes.apple.com';

  Future<SearchResults> search(String term) async {
    final uri = _buildSearchUri(term);
    final response = await httpClient.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'User-Agent': 'PodcastPlayer/1.0 (Flutter)',
      },
    );

    if (response.statusCode != 200) {
      throw ApplePodcastsSearchException(
        '搜尋失敗：${response.reasonPhrase}',
        response.statusCode,
      );
    }

    return _parseResults(response.body);
  }

  Uri _buildSearchUri(String term) {
    final queryParameters = <String, String>{
      'term': term,
      'country': countryCode,
      'media': 'podcast',
      'entity': 'podcast,podcastEpisode',
      'limit': resultLimit.toString(),
      'lang': language,
    };
    return Uri.https(_host, '/search', queryParameters);
  }

  SearchResults _parseResults(String jsonString) {
    final payload = jsonDecode(jsonString) as Map<String, dynamic>;
    final rawResults = payload['results'] as List<dynamic>?;

    if (rawResults == null) {
      return SearchResults.empty;
    }

    final podcasts = <Podcast>[];
    final episodes = <Episode>[];

    for (final raw in rawResults) {
      if (raw is! Map<String, dynamic>) {
        continue;
      }
      final wrapperType = raw['wrapperType'] as String?;
      final kind = raw['kind'] as String?;

      final normalizedKind = (wrapperType ?? kind ?? '').toLowerCase();

      if (normalizedKind.contains('podcastepisode') ||
          normalizedKind.contains('podcast-episode')) {
        final episode = _mapToEpisode(raw);
        if (episode != null) {
          episodes.add(episode);
        }
        continue;
      }

      if (normalizedKind.contains('track') ||
          normalizedKind.contains('podcast')) {
        final podcast = _mapToPodcast(raw);
        if (podcast != null) {
          podcasts.add(podcast);
        }
      }
    }

    return SearchResults(podcasts: podcasts, episodes: episodes);
  }

  Podcast? _mapToPodcast(Map<String, dynamic> json) {
    final feedUrl = json['feedUrl'] as String?;
    final title = (json['collectionName'] ?? json['trackName']) as String?;

    if (feedUrl == null || title == null) {
      return null;
    }

    final idValue = json['collectionId'] ?? json['trackId'] ?? feedUrl;
    final artwork =
        json['artworkUrl600'] ?? json['artworkUrl100'] ?? json['artworkUrl60'];

    return Podcast(
      id: '$idValue',
      title: title,
      author: (json['artistName'] ?? '未知作者') as String,
      feedUrl: feedUrl,
      description: json['description'] as String?,
      artworkUrl: artwork as String?,
      category: json['primaryGenreName'] as String?,
      language: json['country'] as String?,
      episodes: const [],
    );
  }

  Episode? _mapToEpisode(Map<String, dynamic> json) {
    final audioUrl =
        (json['episodeUrl'] ?? json['previewUrl'] ?? json['trackViewUrl'])
            as String?;
    final title = json['trackName'] as String?;
    if (audioUrl == null || title == null) {
      return null;
    }

    final guid = json['episodeGuid'] ?? json['trackId'] ?? audioUrl;

    Duration? duration;
    final trackTime = json['trackTimeMillis'];
    if (trackTime is int) {
      duration = Duration(milliseconds: trackTime);
    } else if (trackTime is String) {
      final parsed = int.tryParse(trackTime);
      if (parsed != null) {
        duration = Duration(milliseconds: parsed);
      }
    }

    DateTime? publishedAt;
    final releaseDate = json['releaseDate'] as String?;
    if (releaseDate != null) {
      publishedAt = DateTime.tryParse(releaseDate);
    }

    return Episode(
      id: '$guid',
      title: title,
      audioUrl: audioUrl,
      description: json['description'] as String?,
      imageUrl: (json['artworkUrl600'] ?? json['artworkUrl100']) as String?,
      duration: duration,
      publishedAt: publishedAt,
      podcastTitle: (json['collectionName'] ?? json['trackName']) as String?,
      podcastAuthor: json['artistName'] as String?,
    );
  }
}

final applePodcastsSearchClientProvider = Provider<ApplePodcastsSearchClient>((
  ref,
) {
  final client = ref.watch(httpClientProvider);
  return ApplePodcastsSearchClient(httpClient: client);
}, name: 'applePodcastsSearchClientProvider');
