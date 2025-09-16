import 'podcast.dart';

class SearchResults {
  const SearchResults({this.podcasts = const [], this.episodes = const []});

  final List<Podcast> podcasts;
  final List<Episode> episodes;

  bool get isEmpty => podcasts.isEmpty && episodes.isEmpty;

  static const empty = SearchResults();
}
