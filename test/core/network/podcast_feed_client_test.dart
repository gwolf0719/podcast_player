import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:podcast_player/core/network/podcast_feed_client.dart';

void main() {
  group('PodcastFeedClient', () {
    late String xmlFixture;

    setUpAll(() async {
      xmlFixture = await File('test/fixtures/podcast_feed.xml').readAsString();
    });

    test('解析 RSS feed 取得單集資訊', () async {
      final client = MockClient((request) async {
        return http.Response(xmlFixture, 200);
      });

      final feedClient = PodcastFeedClient(httpClient: client);
      final episodes = await feedClient.fetchEpisodes('https://example.com/feed');

      expect(episodes, hasLength(2));
      expect(episodes.first.title, contains('Episode One'));
      expect(episodes.first.audioUrl, 'https://example.com/audio1.mp3');
      expect(episodes.first.duration?.inSeconds, 3600);
      expect(episodes.first.imageUrl, 'https://example.com/ep1.jpg');
    });
  });
}
