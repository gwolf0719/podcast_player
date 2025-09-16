import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../data/models/podcast.dart';
import 'http_client_provider.dart';

class ApplePodcastsRssException implements Exception {
  ApplePodcastsRssException(this.message, [this.statusCode]);

  final String message;
  final int? statusCode;

  @override
  String toString() =>
      'ApplePodcastsRssException(statusCode: $statusCode, message: $message)';
}

class ApplePodcastsRssClient {
  ApplePodcastsRssClient({required this.httpClient, this.countryCode = 'tw'});

  final http.Client httpClient;
  final String countryCode;

  static const _host = 'itunes.apple.com';
  static const _atomNamespace = 'http://www.w3.org/2005/Atom';
  static const _itunesNamespace = 'http://itunes.apple.com/rss';

  Future<List<Podcast>> fetchTopPodcasts({
    String? genreId,
    int limit = 50,
  }) async {
    final uri = _buildTopPodcastsUri(limit: limit, genreId: genreId);
    final response = await httpClient.get(
      uri,
      headers: {
        'Accept': 'application/xml',
        'User-Agent': 'PodcastPlayer/1.0 (Flutter)',
      },
    );

    if (response.statusCode != 200) {
      throw ApplePodcastsRssException(
        '無法取得熱門榜單：${response.reasonPhrase}',
        response.statusCode,
      );
    }

    return _parseTopPodcasts(response.body);
  }

  Uri _buildTopPodcastsUri({required int limit, String? genreId}) {
    final buffer = StringBuffer()
      ..write('/$countryCode/rss/toppodcasts/limit=$limit');
    if (genreId != null && genreId.isNotEmpty) {
      buffer.write('/genre=$genreId');
    }
    buffer.write('/xml');
    return Uri.https(_host, buffer.toString());
  }

  List<Podcast> _parseTopPodcasts(String xmlString) {
    final document = XmlDocument.parse(xmlString);
    final entries = document
        .findAllElements('entry', namespace: _atomNamespace)
        .toList(growable: false);

    return entries.map(_mapEntryToPodcast).whereType<Podcast>().toList();
  }

  Podcast? _mapEntryToPodcast(XmlElement entry) {
    XmlElement? alternateLink;
    for (final link in entry.findElements('link', namespace: _atomNamespace)) {
      if (link.getAttribute('rel') == 'alternate') {
        alternateLink = link;
        break;
      }
    }
    final feedLink = alternateLink?.getAttribute('href');
    final titleElement = entry.getElement('name', namespace: _itunesNamespace);

    if (feedLink == null || titleElement == null) {
      return null;
    }

    final artistElement = entry.getElement(
      'artist',
      namespace: _itunesNamespace,
    );

    final summaryElement = entry.getElement(
      'summary',
      namespace: _atomNamespace,
    );

    final categoryElement = entry.getElement(
      'category',
      namespace: _atomNamespace,
    );
    final imageElement = entry
        .findElements('image', namespace: _itunesNamespace)
        .lastOrNull;

    return Podcast(
      id: feedLink,
      title: titleElement.innerText.trim(),
      author: artistElement?.innerText.trim() ?? '未知作者',
      feedUrl: feedLink,
      description: summaryElement?.innerText.trim(),
      category:
          categoryElement?.getAttribute('label') ??
          categoryElement?.getAttribute('term'),
      language: null,
      artworkUrl: imageElement?.innerText.trim(),
      episodes: const [],
    );
  }
}

extension NullableLastExtension<T> on Iterable<T> {
  T? get lastOrNull => isEmpty ? null : last;
}

final applePodcastsRssClientProvider = Provider<ApplePodcastsRssClient>((ref) {
  final client = ref.watch(httpClientProvider);
  return ApplePodcastsRssClient(httpClient: client);
}, name: 'applePodcastsRssClientProvider');
