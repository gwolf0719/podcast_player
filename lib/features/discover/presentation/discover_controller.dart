import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/models/podcast.dart';
import '../../../core/data/repositories/charts_repository.dart';

final discoverControllerProvider =
    AutoDisposeAsyncNotifierProvider<DiscoverController, List<Podcast>>(
      DiscoverController.new,
      name: 'discoverControllerProvider',
    );

class DiscoverController extends AutoDisposeAsyncNotifier<List<Podcast>> {
  @override
  Future<List<Podcast>> build() async {
    return _loadTrending();
  }

  Future<List<Podcast>> refresh({String? genreId}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _loadTrending(genreId: genreId, forceRefresh: true),
    );
    return state.requireValue;
  }

  Future<List<Podcast>> _loadTrending({
    String? genreId,
    bool forceRefresh = false,
  }) {
    final repository = ref.read(chartsRepositoryProvider);
    return repository.fetchTrendingTW(
      genreId: genreId,
      forceRefresh: forceRefresh,
    );
  }
}
