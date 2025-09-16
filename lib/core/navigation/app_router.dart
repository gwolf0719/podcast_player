import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/discover/presentation/discover_page.dart';
import '../../features/library/presentation/library_page.dart';
import '../../features/search/presentation/search_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/home/presentation/home_navigation_scaffold.dart';
import '../../features/podcast/presentation/podcast_page.dart';
import '../../features/episode/presentation/episode_page.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _discoverNavigatorKey = GlobalKey<NavigatorState>();
final _searchNavigatorKey = GlobalKey<NavigatorState>();
final _libraryNavigatorKey = GlobalKey<NavigatorState>();
final _settingsNavigatorKey = GlobalKey<NavigatorState>();

final goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: DiscoverRoute.path,
    navigatorKey: _rootNavigatorKey,
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('導航錯誤')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              Text(
                state.error?.toString() ?? '未知錯誤',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => GoRouter.of(context).go(DiscoverRoute.path),
                child: const Text('回到探索頁'),
              ),
            ],
          ),
        ),
      ),
    ),
    routes: [
      GoRoute(
        path: '/',
        redirect: (_, __) => DiscoverRoute.path,
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeNavigationScaffold(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            navigatorKey: _discoverNavigatorKey,
            routes: [
              GoRoute(
                path: DiscoverRoute.path,
                name: DiscoverRoute.name,
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: DiscoverPage()),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _searchNavigatorKey,
            routes: [
              GoRoute(
                path: SearchRoute.path,
                name: SearchRoute.name,
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: SearchPage()),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _libraryNavigatorKey,
            routes: [
              GoRoute(
                path: LibraryRoute.path,
                name: LibraryRoute.name,
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: LibraryPage()),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _settingsNavigatorKey,
            routes: [
              GoRoute(
                path: SettingsRoute.path,
                name: SettingsRoute.name,
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: SettingsPage()),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: PodcastRoute.path,
        name: PodcastRoute.name,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['podcastId']!;
          return PodcastPage(podcastId: id);
        },
      ),
      GoRoute(
        path: EpisodeRoute.path,
        name: EpisodeRoute.name,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final episodeId = state.pathParameters['episodeId']!;
          return EpisodePage(episodeId: episodeId);
        },
      ),
    ],
  );
});

abstract class DiscoverRoute {
  static const name = 'discover';
  static const path = '/discover';
}

abstract class SearchRoute {
  static const name = 'search';
  static const path = '/search';
}

abstract class LibraryRoute {
  static const name = 'library';
  static const path = '/library';
}

abstract class SettingsRoute {
  static const name = 'settings';
  static const path = '/settings';
}

abstract class PodcastRoute {
  static const name = 'podcast';
  static const path = '/podcast/:podcastId';
}

abstract class EpisodeRoute {
  static const name = 'episode';
  static const path = '/episode/:episodeId';
}
