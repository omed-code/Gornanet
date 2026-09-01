import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/movie.dart';
import '../../state/app_providers.dart';
import '../movie_detail_screen.dart';
import 'movie_poster.dart';

class MovieCard extends ConsumerWidget {
  const MovieCard({required this.movie, super.key});

  final Movie movie;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(
      watchlistProvider.select(
        (state) => state.value?.any((item) => item.id == movie.id) ?? false,
      ),
    );
    return Semantics(
      button: true,
      label: 'Open details for ${movie.title}',
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => MovieDetailScreen(movie: movie),
            ),
          ),
          child: SizedBox(
            height: 156,
            child: Row(
              children: <Widget>[
                AspectRatio(
                  aspectRatio: 2 / 3,
                  child: MoviePoster(url: movie.posterUrl),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          movie.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 7),
                        Row(
                          children: <Widget>[
                            const Icon(
                              Icons.star_rounded,
                              color: Colors.amber,
                              size: 19,
                            ),
                            const SizedBox(width: 4),
                            Text(movie.voteAverage.toStringAsFixed(1)),
                            const SizedBox(width: 12),
                            Text(movie.releaseYear),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Text(
                            movie.overview.isEmpty
                                ? 'No overview is available.'
                                : movie.overview,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  tooltip: saved ? 'Remove from watchlist' : 'Add to watchlist',
                  onPressed: () async {
                    try {
                      await ref.read(watchlistProvider.notifier).toggle(movie);
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Could not update watchlist.'),
                          ),
                        );
                      }
                    }
                  },
                  icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
