import 'package:flutter/material.dart';

import '../../state/app_providers.dart';
import 'movie_card.dart';

class MovieListView extends StatelessWidget {
  const MovieListView({
    required this.data,
    required this.controller,
    required this.onRefresh,
    required this.onLoadMoreRetry,
    super.key,
  });

  final PagedMovies data;
  final ScrollController controller;
  final Future<void> Function() onRefresh;
  final VoidCallback onLoadMoreRetry;

  @override
  Widget build(BuildContext context) {
    final hasFooter = data.isLoadingMore || data.loadMoreError != null;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        key: const Key('movie-list'),
        controller: controller,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        itemCount: data.movies.length + (hasFooter ? 1 : 0),
        itemBuilder: (context, index) {
          if (index < data.movies.length) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: MovieCard(movie: data.movies[index]),
            );
          }
          if (data.isLoadingMore) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: <Widget>[
                Text(data.loadMoreError!, textAlign: TextAlign.center),
                TextButton(
                  onPressed: onLoadMoreRetry,
                  child: const Text('Retry loading more'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
