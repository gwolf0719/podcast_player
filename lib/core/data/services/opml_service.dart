import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xml/xml.dart';

import '../models/podcast.dart';

final opmlServiceProvider = Provider<OpmlService>(
  (ref) => const OpmlService(),
  name: 'opmlServiceProvider',
);

class OpmlService {
  const OpmlService();

  String exportToOpml(List<Podcast> podcasts) {
    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element(
      'opml',
      nest: () {
        builder.attribute('version', '1.0');
        builder.element(
          'head',
          nest: () {
            builder.element('title', nest: 'Podcast Player Subscriptions');
          },
        );
        builder.element(
          'body',
          nest: () {
            for (final podcast in podcasts) {
              builder.element(
                'outline',
                nest: () {
                  builder.attribute('type', 'rss');
                  builder.attribute('text', podcast.title);
                  builder.attribute('title', podcast.title);
                  builder.attribute('xmlUrl', podcast.feedUrl);
                  if (podcast.description != null) {
                    builder.attribute('description', podcast.description!);
                  }
                  if (podcast.artworkUrl != null) {
                    builder.attribute('image', podcast.artworkUrl!);
                  }
                  if (podcast.category != null) {
                    builder.attribute('category', podcast.category!);
                  }
                },
              );
            }
          },
        );
      },
    );

    return builder.buildDocument().toXmlString(pretty: true);
  }

  List<Podcast> importFromOpml(String opmlContent) {
    final document = XmlDocument.parse(opmlContent);
    final outlines = document.findAllElements('outline');
    final podcasts = <Podcast>[];

    for (final outline in outlines) {
      final xmlUrl =
          outline.getAttribute('xmlUrl') ?? outline.getAttribute('xmlurl');
      if (xmlUrl == null || xmlUrl.isEmpty) {
        continue;
      }
      final title =
          outline.getAttribute('title') ??
          outline.getAttribute('text') ??
          xmlUrl;

      podcasts.add(
        Podcast(
          id: xmlUrl,
          title: title,
          author: outline.getAttribute('author') ?? '未知作者',
          feedUrl: xmlUrl,
          description: outline.getAttribute('description'),
          artworkUrl: outline.getAttribute('image'),
          category: outline.getAttribute('category'),
          language: null,
          episodes: const [],
        ),
      );
    }

    return podcasts;
  }
}
