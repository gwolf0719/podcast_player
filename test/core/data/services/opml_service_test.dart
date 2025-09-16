import 'package:flutter_test/flutter_test.dart';

import 'package:podcast_player/core/data/models/podcast.dart';
import 'package:podcast_player/core/data/services/opml_service.dart';

void main() {
  group('OpmlService', () {
    const service = OpmlService();

    test('export 產生含有節目資訊的 OPML', () {
      final opml = service.exportToOpml(const [
        Podcast(
          id: 'swift-talk',
          title: 'Swift Talk 台灣',
          author: 'Swift 社群',
          feedUrl: 'https://example.com/swift.xml',
          description: 'Swift 與行動開發',
          category: 'Technology',
          episodes: [],
        ),
      ]);

      expect(opml, contains('<opml'));
      expect(opml, contains('Swift Talk 台灣'));
      expect(opml, contains('https://example.com/swift.xml'));
    });

    test('import 解析出訂閱節目', () {
      const opml = '''
<?xml version="1.0" encoding="UTF-8"?>
<opml version="1.0">
  <body>
    <outline text="Swift Talk 台灣" xmlUrl="https://example.com/swift.xml" title="Swift Talk 台灣" />
    <outline text="Dev Life" xmlUrl="https://example.com/dev.xml" />
  </body>
</opml>
''';

      final podcasts = service.importFromOpml(opml);

      expect(podcasts, hasLength(2));
      expect(podcasts.first.feedUrl, 'https://example.com/swift.xml');
      expect(podcasts.last.title, 'Dev Life');
    });
  });
}
