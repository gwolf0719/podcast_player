import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../network/apple_podcasts_search_client.dart';
import '../models/search_results.dart';

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  final client = ref.watch(applePodcastsSearchClientProvider);
  return SearchRepository(searchClient: client);
}, name: 'searchRepositoryProvider');

class SearchRepository {
  SearchRepository({required this.searchClient});

  final ApplePodcastsSearchClient searchClient;

  Future<SearchResults> searchRemote(String query) async {
    if (query.trim().isEmpty) {
      return SearchResults.empty;
    }
    return searchClient.search(query);
  }
}
