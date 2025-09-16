import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:podcast_player/core/data/models/search_results.dart';
import 'package:podcast_player/core/data/repositories/search_repository.dart';
import 'package:podcast_player/core/network/apple_podcasts_search_client.dart';

class FakeApplePodcastsSearchClient extends ApplePodcastsSearchClient {
  FakeApplePodcastsSearchClient({required this.results})
    : super(httpClient: http.Client());

  final SearchResultsStub results;

  @override
  Future<SearchResults> search(String term) async {
    results.calls += 1;
    return results.value;
  }
}

class SearchResultsStub {
  SearchResultsStub(this.value);

  int calls = 0;
  final SearchResults value;
}

void main() {
  test('空白關鍵字不會呼叫 API', () async {
    final stub = SearchResultsStub(const SearchResults());
    final client = FakeApplePodcastsSearchClient(results: stub);
    final repository = SearchRepository(searchClient: client);

    final result = await repository.searchRemote('   ');

    expect(result.isEmpty, isTrue);
    expect(stub.calls, 0);
  });
}
