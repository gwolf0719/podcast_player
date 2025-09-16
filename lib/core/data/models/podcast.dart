class Podcast {
  const Podcast({
    required this.id,
    required this.title,
    required this.author,
    required this.feedUrl,
    required this.episodes,
    this.artworkUrl,
    this.description,
    this.category,
    this.language,
  });

  final String id;
  final String title;
  final String author;
  final String feedUrl;
  final List<Episode> episodes;
  final String? artworkUrl;
  final String? description;
  final String? category;
  final String? language;
}

class Episode {
  const Episode({
    required this.id,
    required this.title,
    required this.audioUrl,
    this.description,
    this.publishedAt,
    this.duration,
    this.imageUrl,
    this.podcastTitle,
    this.podcastAuthor,
    this.podcastFeedUrl,
  });

  final String id;
  final String title;
  final String audioUrl;
  final String? description;
  final DateTime? publishedAt;
  final Duration? duration;
  final String? imageUrl;
  final String? podcastTitle;
  final String? podcastAuthor;
  final String? podcastFeedUrl;
}
