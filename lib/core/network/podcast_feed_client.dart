import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../data/models/podcast.dart' as models show Episode;
import 'http_client_provider.dart';

final podcastFeedClientProvider = Provider<PodcastFeedClient>((ref) {
  final client = ref.watch(httpClientProvider);
  return PodcastFeedClient(httpClient: client);
}, name: 'podcastFeedClientProvider');

class PodcastFeedClient {
  PodcastFeedClient({required this.httpClient});

  final http.Client httpClient;

  Future<List<models.Episode>> fetchEpisodes(String feedUrl) async {
    final response = await httpClient.get(Uri.parse(feedUrl));
    if (response.statusCode != 200) {
      throw Exception('無法載入 feed：${response.reasonPhrase}');
    }

    return _parseFeed(response.body);
  }

  List<models.Episode> _parseFeed(String xmlString) {
    final document = XmlDocument.parse(xmlString);
    final items = document.findAllElements('item').toList(growable: false);

    return items.map(_mapItemToEpisode).whereType<models.Episode>().toList();
  }

  models.Episode? _mapItemToEpisode(XmlElement item) {
    final guidElement = item.getElement('guid');
    final titleElement = item.getElement('title');

    final enclosure = item.getElement('enclosure');
    final audioUrl = enclosure?.getAttribute('url') ??
        item.getElement('link')?.innerText.trim();

    if ((guidElement == null && audioUrl == null) || titleElement == null) {
      return null;
    }

    final id = guidElement?.innerText.trim() ?? audioUrl!;
    final description = item.getElement('description')?.innerText.trim();
    final pubDateText = item.getElement('pubDate')?.innerText.trim();
    DateTime? publishedAt;
    if (pubDateText != null) {
      publishedAt = DateTime.tryParse(pubDateText);
    }

    Duration? duration;
    final durationText = item.getElement('itunes:duration')?.innerText.trim();
    if (durationText != null) {
      duration = _tryParseDuration(durationText);
    }

    final imageUrl = item.getElement('itunes:image')?.getAttribute('href');

    return models.Episode(
      id: id,
      title: titleElement.innerText.trim(),
      audioUrl: audioUrl ?? '',
      description: description,
      publishedAt: publishedAt,
      duration: duration,
      imageUrl: imageUrl,
    );
  }

  Duration? _tryParseDuration(String input) {
    final parts = input.split(':');
    if (parts.length == 3) {
      final hours = int.tryParse(parts[0]);
      final minutes = int.tryParse(parts[1]);
      final seconds = int.tryParse(parts[2]);
      if (hours != null && minutes != null && seconds != null) {
        return Duration(hours: hours, minutes: minutes, seconds: seconds);
      }
    }

    final totalSeconds = int.tryParse(input);
    if (totalSeconds != null) {
      return Duration(seconds: totalSeconds);
    }

    return null;
  }
}
