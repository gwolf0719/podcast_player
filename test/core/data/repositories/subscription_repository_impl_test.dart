import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:podcast_player/core/data/models/podcast.dart';
import 'package:podcast_player/core/data/repositories/subscription_repository.dart';
import 'package:podcast_player/core/db/subscription_database.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late SubscriptionRepository repository;
  late SubscriptionDatabase database;
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('subscription_repo');
    database = SubscriptionDatabase(
      overridePath: p.join(tempDir.path, 'subscriptions.db'),
    );
    repository = SubscriptionRepository(database: database);
    await Future<void>.delayed(const Duration(milliseconds: 50));
  });

  tearDown(() async {
    await database.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  final samplePodcast = const Podcast(
    id: 'swift-talk',
    title: 'Swift Talk 台灣',
    author: 'Swift 社群',
    feedUrl: 'https://example.com/swift.xml',
    episodes: [],
  );

  test('subscribe 與 unsubscribe 更新清單', () async {
    expect(repository.current, isEmpty);

    await repository.subscribe(samplePodcast);
    expect(repository.current, hasLength(1));
    expect(repository.isSubscribed(samplePodcast.feedUrl), isTrue);

    await repository.unsubscribe(samplePodcast.feedUrl);
    expect(repository.current, isEmpty);
    expect(repository.isSubscribed(samplePodcast.feedUrl), isFalse);
  });

  test('listener 會即時收到更新', () async {
    var calls = 0;
    List<Podcast> latest = const [];
    repository.addListener((pods) {
      calls += 1;
      latest = pods;
    });

    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(calls, 1);
    expect(latest, isEmpty);

    await repository.subscribe(samplePodcast);
    expect(calls, 2);
    expect(latest, hasLength(1));

    await repository.unsubscribe(samplePodcast.feedUrl);
    expect(calls, 3);
    expect(latest, isEmpty);
  });
}
