import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../state/app_providers.dart';
import 'search_screen.dart';
import 'trending_screen.dart';
import 'watchlist_screen.dart';
import 'widgets/spider_web_background.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell>
    with SingleTickerProviderStateMixin {
  int _index = 0;
  late final AnimationController _tabTransitionController;
  late final Animation<double> _tabOpacity;

  static const _titles = <String>[
    'Trending today',
    'Find a title',
    'Watchlist',
  ];

  @override
  void initState() {
    super.initState();
    _tabTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 1,
    );
    _tabOpacity = Tween<double>(begin: .92, end: 1).animate(
      CurvedAnimation(
        parent: _tabTransitionController,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  void _selectTab(int index) {
    if (_index == index) return;
    setState(() => _index = index);
    _tabTransitionController.forward(from: 0);
  }

  @override
  void dispose() {
    _tabTransitionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SpiderWebBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
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
                          width: 22,
                          height: 22,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Text(
                        'SPIDER MOVIE',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: 2.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          title: Padding(
            padding: const EdgeInsets.only(top: 22),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _titles[_index],
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
          ),
          actions: <Widget>[
            if (_index != 1)
              Padding(
                padding: const EdgeInsets.only(top: 22),
                child: IconButton.filledTonal(
                  key: const Key('app-bar-search'),
                  tooltip: 'Search',
                  style: IconButton.styleFrom(
                    minimumSize: const Size.square(40),
                    maximumSize: const Size.square(40),
                    iconSize: 21,
                  ),
                  onPressed: () => _selectTab(1),
                  icon: const Icon(Symbols.manage_search_rounded),
                ),
              ),
            const Padding(
              padding: EdgeInsets.only(top: 22),
              child: _ThemeModeMenu(),
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: SafeArea(
          top: false,
          child: FadeTransition(
            opacity: _tabOpacity,
            child: IndexedStack(
              index: _index,
              children: <Widget>[
                const TrendingScreen(),
                SearchScreen(isActive: _index == 1),
                const WatchlistScreen(),
              ],
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          minimum: const EdgeInsets.only(bottom: 6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Material(
              key: const Key('modern-bottom-navigation'),
              elevation: 3,
              shadowColor: Theme.of(
                context,
              ).colorScheme.shadow.withValues(alpha: .10),
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainer.withValues(alpha: .96),
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
                side: BorderSide(
                  color: Theme.of(
                    context,
                  ).colorScheme.outlineVariant.withValues(alpha: .55),
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
                        icon: Symbols.local_fire_department,
                        selectedIcon: Symbols.local_fire_department_rounded,
                        selected: _index == 0,
                        onTap: () => _selectTab(0),
                      ),
                      _BottomNavigationItem(
                        label: 'Search',
                        icon: Symbols.search_rounded,
                        selectedIcon: Symbols.manage_search_rounded,
                        selected: _index == 1,
                        onTap: () => _selectTab(1),
                      ),
                      _BottomNavigationItem(
                        label: 'Watchlist',
                        icon: Symbols.bookmark_border_rounded,
                        selectedIcon: Symbols.bookmark_rounded,
                        selected: _index == 2,
                        onTap: () => _selectTab(2),
                      ),
                    ],
                  ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedBackground = Color.alphaBlend(
      scheme.primary.withValues(alpha: isDark ? .14 : .10),
      scheme.surfaceContainerHighest,
    );
    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        label: label,
        child: AnimatedContainer(
          key: Key('bottom-navigation-$label'),
          duration: const Duration(milliseconds: 360),
          curve: Curves.easeInOutCubic,
          decoration: BoxDecoration(
            color: selected ? selectedBackground : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            border: selected
                ? Border.all(color: scheme.primary.withValues(alpha: .18))
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 320),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: Icon(
                        selected ? selectedIcon : icon,
                        key: ValueKey<bool>(selected),
                        size: 22,
                        color: selected
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      maxLines: 1,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: selected
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                        fontWeight: selected
                            ? FontWeight.w700
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
    final scheme = Theme.of(context).colorScheme;
    final icon = switch (selected) {
      ThemeMode.light => Symbols.light_mode,
      ThemeMode.dark => Symbols.dark_mode,
      ThemeMode.system => Symbols.brightness_auto,
    };
    return Material(
      color: scheme.primary,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: SizedBox.square(
        dimension: 40,
        child: PopupMenuButton<ThemeMode>(
          tooltip: 'Choose theme',
          padding: EdgeInsets.zero,
          iconSize: 22,
          iconColor: scheme.onPrimary,
          icon: Icon(icon),
          initialValue: selected,
          onSelected: (mode) async {
            try {
              await ref.read(themeModeProvider.notifier).setMode(mode);
            } catch (_) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Could not save theme preference.'),
                  ),
                );
              }
            }
          },
          itemBuilder: (context) => const <PopupMenuEntry<ThemeMode>>[
            PopupMenuItem(value: ThemeMode.system, child: Text('System theme')),
            PopupMenuItem(value: ThemeMode.light, child: Text('Light theme')),
            PopupMenuItem(value: ThemeMode.dark, child: Text('Dark theme')),
          ],
        ),
      ),
    );
  }
}
