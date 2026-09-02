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
          return const StatePanel(
            icon: Symbols.bookmark_add,
            title: 'Your watchlist is empty',
            message:
                'Save movies from Trending, Search, or a detail page. They will remain here offline.',
          );
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
