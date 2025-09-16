import 'package:podcast_player/core/data/models/podcast.dart';

const samplePodcasts = <Podcast>[
  Podcast(
    id: 'swift-talk',
    title: 'Swift Talk 台灣',
    author: 'Swift 社群',
    feedUrl: 'https://example.com/swift-talk.xml',
    description: '分享 Swift 與行動開發的新知與產業動態。',
    category: 'Technology',
    language: 'zh-TW',
    episodes: [
      Episode(
        id: 'swift-talk-001',
        title: '導論：打造跨平台 Podcast 體驗',
        audioUrl:
            'https://traffic.libsyn.com/secure/dartlang/Flutter-Dev-Podcast-002.mp3',
        description: '討論探索面向的產品規劃與設計重點。',
        duration: Duration(minutes: 28, seconds: 12),
        podcastTitle: 'Swift Talk 台灣',
        podcastAuthor: 'Swift 社群',
      ),
      Episode(
        id: 'swift-talk-002',
        title: 'RSS 與排行榜整合',
        audioUrl:
            'https://traffic.libsyn.com/secure/dartlang/Flutter-Dev-Podcast-003.mp3',
        description: '解析 Apple Podcasts 排行與 RSS 快取策略。',
        duration: Duration(minutes: 31, seconds: 40),
        podcastTitle: 'Swift Talk 台灣',
        podcastAuthor: 'Swift 社群',
      ),
    ],
  ),
  Podcast(
    id: 'dev-life',
    title: 'Dev Life 生活與程式',
    author: 'Dev Life',
    feedUrl: 'https://example.com/dev-life.xml',
    description: '訪談開發者與產品經理的工作歷程。',
    category: 'Business',
    language: 'zh-TW',
    episodes: [
      Episode(
        id: 'dev-life-120',
        title: '排程與背景作業的一天',
        audioUrl:
            'https://traffic.libsyn.com/secure/dartlang/Flutter-Dev-Podcast-004.mp3',
        description: 'WorkManager 與自動下載的最佳實務。',
        duration: Duration(minutes: 42, seconds: 8),
        podcastTitle: 'Dev Life 生活與程式',
        podcastAuthor: 'Dev Life',
      ),
    ],
  ),
];
