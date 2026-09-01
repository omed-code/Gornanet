import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/app_providers.dart';
import 'search_screen.dart';
import 'trending_screen.dart';
import 'watchlist_screen.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  static const _titles = <String>[
    'Trending today',
    'Find a title',
    'Watchlist',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        flexibleSpace: SafeArea(
          child: IgnorePointer(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: Image.asset(
                        'assets/branding/spider_movie_icon.png',
                        key: const Key('app-bar-logo'),
                        width: 20,
                        height: 20,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'SPIDER MOVIE',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        title: Padding(
          padding: const EdgeInsets.only(top: 15),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _titles[_index],
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
        ),
        actions: <Widget>[
          IconButton(
            key: const Key('app-bar-search'),
            tooltip: 'Search',
            onPressed: () => setState(() => _index = 1),
            icon: const Icon(Icons.search_rounded),
          ),
          const _ThemeModeMenu(),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        top: false,
        child: IndexedStack(
          index: _index,
          children: <Widget>[
            const TrendingScreen(),
            SearchScreen(isActive: _index == 1),
            const WatchlistScreen(),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
          child: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (index) => setState(() => _index = index),
            destinations: const <NavigationDestination>[
              NavigationDestination(
                icon: Icon(Icons.local_fire_department_outlined),
                selectedIcon: Icon(Icons.local_fire_department_rounded),
                label: 'Trending',
              ),
              NavigationDestination(
                icon: Icon(Icons.search_rounded),
                selectedIcon: Icon(Icons.manage_search_rounded),
                label: 'Search',
              ),
              NavigationDestination(
                icon: Icon(Icons.bookmark_border_rounded),
                selectedIcon: Icon(Icons.bookmark_rounded),
                label: 'Watchlist',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeModeMenu extends ConsumerWidget {
  const _ThemeModeMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(themeModeProvider).value ?? ThemeMode.system;
    return PopupMenuButton<ThemeMode>(
      tooltip: 'Choose theme',
      icon: const Icon(Icons.contrast_rounded),
      initialValue: selected,
      onSelected: (mode) async {
        try {
          await ref.read(themeModeProvider.notifier).setMode(mode);
        } catch (_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not save theme preference.')),
            );
          }
        }
      },
      itemBuilder: (context) => const <PopupMenuEntry<ThemeMode>>[
        PopupMenuItem(value: ThemeMode.system, child: Text('System theme')),
        PopupMenuItem(value: ThemeMode.light, child: Text('Light theme')),
        PopupMenuItem(value: ThemeMode.dark, child: Text('Dark theme')),
      ],
    );
  }
}
