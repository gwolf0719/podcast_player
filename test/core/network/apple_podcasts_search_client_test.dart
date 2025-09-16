import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:podcast_player/core/network/apple_podcasts_search_client.dart';

void main() {
  group('ApplePodcastsSearchClient', () {
    late String jsonFixture;

    setUpAll(() async {
      jsonFixture = await File(
        'test/fixtures/apple_search_results.json',
      ).readAsString();
    });

    test('解析搜尋結果並拆分節目與單集', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/search');
        expect(request.url.queryParameters['entity'], 'podcast,podcastEpisode');
        return http.Response.bytes(
          utf8.encode(jsonFixture),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final searchClient = ApplePodcastsSearchClient(httpClient: client);
      final result = await searchClient.search('Swift');

      expect(result.podcasts, hasLength(2));
      expect(result.podcasts.first.title, 'Swift Talk 台灣');
      expect(result.episodes, hasLength(1));
      expect(result.episodes.first.title, '排程與背景作業的一天');
      expect(result.episodes.first.duration?.inMinutes, 33);
    });

    test('非 200 回應時拋出例外', () async {
      final client = MockClient((request) async {
        return http.Response('Oops', 429, reasonPhrase: 'Too Many Requests');
      });

      final searchClient = ApplePodcastsSearchClient(httpClient: client);

      expect(
        () => searchClient.search('Swift'),
        throwsA(isA<ApplePodcastsSearchException>()),
      );
    });
  });
}
