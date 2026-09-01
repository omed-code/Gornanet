import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/app_providers.dart';
import 'widgets/movie_list_view.dart';
import 'widgets/state_panel.dart';

class TrendingScreen extends ConsumerStatefulWidget {
  const TrendingScreen({super.key});

  @override
  ConsumerState<TrendingScreen> createState() => _TrendingScreenState();
}

class _TrendingScreenState extends ConsumerState<TrendingScreen> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 500) {
      ref.read(trendingProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(trendingProvider);
    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => StatePanel(
        icon: Icons.cloud_off_outlined,
        title: 'Could not load trending movies',
        message: readableError(error),
        actionLabel: 'Try again',
        onAction: () => ref.read(trendingProvider.notifier).refresh(),
      ),
      data: (data) {
        if (data.movies.isEmpty) {
          return StatePanel(
            icon: Icons.movie_filter_outlined,
            title: 'Nothing is trending',
            message: 'TMDB did not return any movies. Pull down to try again.',
            actionLabel: 'Refresh',
            onAction: () => ref.read(trendingProvider.notifier).refresh(),
          );
        }
        return MovieListView(
          data: data,
          controller: _scrollController,
          onRefresh: ref.read(trendingProvider.notifier).refresh,
          onLoadMoreRetry: () => ref.read(trendingProvider.notifier).loadMore(),
        );
      },
    );
  }
}
