import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../player/presentation/mini_player.dart';

class HomeNavigationScaffold extends StatelessWidget {
  const HomeNavigationScaffold({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _titles = <String>['探索', '搜尋', '資料庫', '設定'];

  void _onDestinationSelected(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[navigationShell.currentIndex]),
        backgroundColor: theme.colorScheme.surface,
      ),
      body: navigationShell,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MiniPlayer(),
            NavigationBar(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: _onDestinationSelected,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.explore_outlined),
                  selectedIcon: Icon(Icons.explore),
                  label: '探索',
                ),
                NavigationDestination(icon: Icon(Icons.search), label: '搜尋'),
                NavigationDestination(
                  icon: Icon(Icons.library_books_outlined),
                  selectedIcon: Icon(Icons.library_books),
                  label: '資料庫',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: '設定',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
