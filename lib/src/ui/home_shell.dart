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
        minimum: const EdgeInsets.only(bottom: 6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Material(
            key: const Key('modern-bottom-navigation'),
            elevation: 6,
            shadowColor: Theme.of(
              context,
            ).colorScheme.shadow.withValues(alpha: .12),
            color: Theme.of(context).colorScheme.surfaceContainer,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(32),
              side: BorderSide(
                color: Theme.of(
                  context,
                ).colorScheme.outlineVariant.withValues(alpha: .75),
              ),
            ),
            child: SizedBox(
              height: 64,
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: Row(
                  children: <Widget>[
                    _BottomNavigationItem(
                      label: 'Trending',
                      icon: Icons.local_fire_department_outlined,
                      selectedIcon: Icons.local_fire_department_rounded,
                      selected: _index == 0,
                      onTap: () => setState(() => _index = 0),
                    ),
                    _BottomNavigationItem(
                      label: 'Search',
                      icon: Icons.search_rounded,
                      selectedIcon: Icons.manage_search_rounded,
                      selected: _index == 1,
                      onTap: () => setState(() => _index = 1),
                    ),
                    _BottomNavigationItem(
                      label: 'Watchlist',
                      icon: Icons.bookmark_border_rounded,
                      selectedIcon: Icons.bookmark_rounded,
                      selected: _index == 2,
                      onTap: () => setState(() => _index = 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavigationItem extends StatelessWidget {
  const _BottomNavigationItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        label: label,
        child: AnimatedContainer(
          key: Key('bottom-navigation-$label'),
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeInOutCubic,
          decoration: BoxDecoration(
            color: selected ? scheme.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(27),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(27),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: Icon(
                        selected ? selectedIcon : icon,
                        key: ValueKey<bool>(selected),
                        size: 22,
                        color: selected
                            ? scheme.onPrimaryContainer
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      maxLines: 1,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: selected
                            ? scheme.onPrimaryContainer
                            : scheme.onSurfaceVariant,
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
