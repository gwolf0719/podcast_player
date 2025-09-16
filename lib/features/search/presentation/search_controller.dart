import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/models/search_results.dart';
import '../../../core/data/repositories/search_repository.dart';

final searchControllerProvider =
    AutoDisposeNotifierProvider<SearchController, SearchState>(
      SearchController.new,
      name: 'searchControllerProvider',
    );

class SearchState {
  const SearchState({
    required this.query,
    required this.results,
    required this.hasSearched,
  });

  final String query;
  final AsyncValue<SearchResults> results;
  final bool hasSearched;

  SearchState copyWith({
    String? query,
    AsyncValue<SearchResults>? results,
    bool? hasSearched,
  }) {
    return SearchState(
      query: query ?? this.query,
      results: results ?? this.results,
      hasSearched: hasSearched ?? this.hasSearched,
    );
  }

  static SearchState initial() => SearchState(
    query: '',
    results: const AsyncValue.data(SearchResults.empty),
    hasSearched: false,
  );
}

class SearchController extends AutoDisposeNotifier<SearchState> {
  @override
  SearchState build() => SearchState.initial();

  void updateQuery(String query) {
    state = state.copyWith(query: query);
    if (query.trim().isEmpty) {
      state = SearchState.initial();
    }
  }

  Future<void> submit() async {
    final query = state.query.trim();
    if (query.isEmpty) {
      state = SearchState.initial();
      return;
    }

    state = state.copyWith(
      results: const AsyncValue.loading(),
      hasSearched: true,
    );

    try {
      final result = await ref
          .read(searchRepositoryProvider)
          .searchRemote(query);
      state = state.copyWith(
        results: AsyncValue.data(result),
        hasSearched: true,
      );
    } catch (error, stackTrace) {
      state = state.copyWith(
        results: AsyncValue.error(error, stackTrace),
        hasSearched: true,
      );
    }
  }
}
