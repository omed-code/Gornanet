import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../state/app_providers.dart';
import 'widgets/movie_card.dart';
import 'widgets/state_panel.dart';

class WatchlistScreen extends ConsumerWidget {
  const WatchlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final watchlist = ref.watch(watchlistProvider);
    return watchlist.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => StatePanel(
        icon: Symbols.error,
        title: 'Could not open watchlist',
        message: readableError(error),
        actionLabel: 'Try again',
        onAction: () => ref.invalidate(watchlistProvider),
      ),
      data: (movies) {
        if (movies.isEmpty) {
          return const _EmptyWatchlist();
        }
        return ListView.builder(
          key: const Key('watchlist-list'),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          itemCount: movies.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: _WatchlistSummary(count: movies.length),
              );
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: MovieCard(movie: movies[index - 1]),
            );
          },
        );
      },
    );
  }
}

class _EmptyWatchlist extends ConsumerWidget {
  const _EmptyWatchlist();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recommendations = ref.watch(homeFeedProvider);
    final movies = recommendations.value?.movies.take(3).toList() ?? const [];
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      key: const Key('empty-watchlist-recommendations'),
      padding: const EdgeInsets.fromLTRB(20, 42, 20, 32),
      children: <Widget>[
        Center(
          child: Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              Symbols.bookmark_add,
              size: 40,
              color: scheme.onPrimaryContainer,
            ),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'Your watchlist is empty',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 10),
        Text(
          'Save movies from Trending, Search, or a detail page. '
          'They will remain here offline.',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 36),
        Row(
          children: <Widget>[
            Icon(Symbols.auto_awesome_rounded, color: scheme.primary),
            const SizedBox(width: 9),
            Text(
              'Recommended for you',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (recommendations.isLoading && movies.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (movies.isEmpty)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: scheme.surfaceContainer,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              'Recommendations are unavailable right now.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          )
        else
          for (var index = 0; index < movies.length; index++) ...<Widget>[
            MovieCard(movie: movies[index]),
            if (index != movies.length - 1) const SizedBox(height: 14),
          ],
      ],
    );
  }
}

class _WatchlistSummary extends StatelessWidget {
  const _WatchlistSummary({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: const <Color>[Color(0xFF741B2D), Color(0xFF1D438A)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: .16)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF2855C7).withValues(alpha: .16),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .94),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Symbols.offline_pin_rounded,
              color: Color(0xFFC62828),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '$count ${count == 1 ? 'title' : 'titles'} saved',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Available even when you are offline',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: .82),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
