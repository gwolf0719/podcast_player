import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:podcast_player/core/data/models/podcast.dart';
import 'package:podcast_player/core/data/models/search_results.dart';
import 'package:podcast_player/core/data/repositories/search_repository.dart';
import 'package:podcast_player/core/network/apple_podcasts_search_client.dart';
import 'package:podcast_player/features/search/presentation/search_controller.dart';

class _FakeSearchClient extends ApplePodcastsSearchClient {
  _FakeSearchClient({required this.results, this.shouldThrow = false})
    : super(httpClient: http.Client());

  final SearchResults results;
  final bool shouldThrow;

  @override
  Future<SearchResults> search(String term) async {
    if (shouldThrow) {
      throw ApplePodcastsSearchException('Rate limit');
    }
    return results;
  }
}

void main() {
  final sampleResults = SearchResults(
    podcasts: const [
      Podcast(
        id: 'swift-talk',
        title: 'Swift Talk 台灣',
        author: 'Swift 社群',
        feedUrl: 'https://example.com/swift-talk.xml',
        episodes: [],
      ),
    ],
    episodes: const [],
  );

  test('成功搜尋後更新結果', () async {
    final container = ProviderContainer(
      overrides: [
        searchRepositoryProvider.overrideWithValue(
          SearchRepository(
            searchClient: _FakeSearchClient(results: sampleResults),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(searchControllerProvider.notifier);

    notifier.updateQuery('Swift');
    await notifier.submit();

    final state = container.read(searchControllerProvider);
    expect(state.results.value?.podcasts, isNotEmpty);
    expect(state.hasSearched, isTrue);
  });

  test('搜尋失敗會回傳錯誤狀態', () async {
    final container = ProviderContainer(
      overrides: [
        searchRepositoryProvider.overrideWithValue(
          SearchRepository(
            searchClient: _FakeSearchClient(
              results: SearchResults.empty,
              shouldThrow: true,
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(searchControllerProvider.notifier);

    notifier.updateQuery('Swift');
    await notifier.submit();

    final state = container.read(searchControllerProvider);
    expect(state.results.hasError, isTrue);
    expect(state.hasSearched, isTrue);
  });
}
