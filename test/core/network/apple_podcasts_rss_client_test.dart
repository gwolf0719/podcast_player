import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:podcast_player/core/network/apple_podcasts_rss_client.dart';

void main() {
  group('ApplePodcastsRssClient', () {
    late String xmlFixture;

    setUpAll(() async {
      xmlFixture = await File(
        'test/fixtures/apple_podcasts_top.xml',
      ).readAsString();
    });

    test('成功解析榜單 XML 並回傳 Podcast 清單', () async {
      final client = MockClient((request) async {
        return http.Response(xmlFixture, 200);
      });

      final rssClient = ApplePodcastsRssClient(httpClient: client);
      final result = await rssClient.fetchTopPodcasts();

      expect(result, hasLength(2));
      expect(result.first.title, 'Sample Podcast A');
      expect(result.first.artworkUrl, 'https://example.com/a-600.jpg');
      expect(result.first.category, 'Technology');
      expect(result.first.feedUrl, 'https://feeds.example.com/sample-a');
      expect(result.first.author, 'Sample Artist A');
    });

    test('遇到非 200 回應會丟出例外', () async {
      final client = MockClient((request) async {
        return http.Response('error', 500, reasonPhrase: 'Internal');
      });

      final rssClient = ApplePodcastsRssClient(httpClient: client);

      expect(
        () => rssClient.fetchTopPodcasts(),
        throwsA(isA<ApplePodcastsRssException>()),
      );
    });
  });
}
