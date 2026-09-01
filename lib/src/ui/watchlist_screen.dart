import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
        icon: Icons.error_outline,
        title: 'Could not open watchlist',
        message: readableError(error),
        actionLabel: 'Try again',
        onAction: () => ref.invalidate(watchlistProvider),
      ),
      data: (movies) {
        if (movies.isEmpty) {
          return const StatePanel(
            icon: Icons.bookmark_add_outlined,
            title: 'Your watchlist is empty',
            message:
                'Save movies from Trending, Search, or a detail page. They will remain here offline.',
          );
        }
        return ListView.builder(
          key: const Key('watchlist-list'),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          itemCount: movies.length,
          itemBuilder: (context, index) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: MovieCard(movie: movies[index]),
          ),
        );
      },
    );
  }
}
