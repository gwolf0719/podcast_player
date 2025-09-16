import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/models/podcast.dart';
import '../../../core/data/repositories/subscription_repository.dart';

final subscriptionControllerProvider =
    StateNotifierProvider<SubscriptionController, List<Podcast>>((ref) {
      final repository = ref.watch(subscriptionRepositoryProvider);
      return SubscriptionController(repository);
    }, name: 'subscriptionControllerProvider');

class SubscriptionController extends StateNotifier<List<Podcast>> {
  SubscriptionController(this._repository) : super(const []) {
    _repository.addListener(_onRepositoryChanged);
  }

  final SubscriptionRepository _repository;

  void _onRepositoryChanged(List<Podcast> podcasts) {
    state = podcasts;
  }

  Future<void> subscribe(Podcast podcast) async {
    await _repository.subscribe(podcast);
  }

  Future<void> unsubscribe(String feedUrl) async {
    await _repository.unsubscribe(feedUrl);
  }

  bool isSubscribed(String feedUrl) => _repository.isSubscribed(feedUrl);

  @override
  void dispose() {
    _repository.removeListener(_onRepositoryChanged);
    super.dispose();
  }
}
