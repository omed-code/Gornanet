import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/tmdb_client.dart';
import '../models/movie.dart';
import '../repositories/movie_repository.dart';
import '../state/app_providers.dart';
import 'widgets/credential_dialog.dart';
import 'widgets/movie_card.dart';
import 'widgets/state_panel.dart';

class TrendingScreen extends ConsumerWidget {
  const TrendingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeFeedProvider);
    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) {
        final credentialError =
            error is AppException &&
            (error.type == AppErrorType.configuration ||
                error.type == AppErrorType.unauthorized);
        return StatePanel(
          icon: credentialError
              ? Icons.key_off_outlined
              : Icons.cloud_off_outlined,
          title: credentialError
              ? 'TMDB setup required'
              : 'Could not load trending movies',
          message: readableError(error),
          actionLabel: credentialError ? 'Add credential' : 'Try again',
          onAction: credentialError
              ? () => showTmdbCredentialDialog(context, ref)
              : () => ref.read(homeFeedProvider.notifier).refresh(),
        );
      },
      data: (data) {
        if (data.movies.isEmpty && data.series.isEmpty && data.anime.isEmpty) {
          return StatePanel(
            icon: Icons.movie_filter_outlined,
            title: 'Nothing to show',
            message: 'TMDB did not return any titles. Pull down to try again.',
            actionLabel: 'Refresh',
            onAction: () => ref.read(homeFeedProvider.notifier).refresh(),
          );
        }
        return RefreshIndicator(
          onRefresh: ref.read(homeFeedProvider.notifier).refresh,
          child: ListView(
            key: const Key('home-sections-list'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: <Widget>[
              _GenreSection(
                feed: data,
                onSelected: ref.read(homeFeedProvider.notifier).selectGenre,
              ),
              const SizedBox(height: 24),
              _MediaSection(
                title: 'Movies',
                icon: Icons.movie_outlined,
                movies: data.movies,
              ),
              const SizedBox(height: 24),
              _MediaSection(
                title: 'Series',
                icon: Icons.tv_outlined,
                movies: data.series,
              ),
              const SizedBox(height: 24),
              _MediaSection(
                title: 'Anime',
                icon: Icons.animation_outlined,
                movies: data.anime,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GenreSection extends StatelessWidget {
  const _GenreSection({required this.feed, required this.onSelected});

  final HomeFeed feed;
  final ValueChanged<BrowseGenre> onSelected;

  @override
  Widget build(BuildContext context) {
    final cardWidth = (MediaQuery.sizeOf(context).width - 56).clamp(
      280.0,
      360.0,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(
              Icons.theater_comedy_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text('Genres', style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 42,
          child: ListView.separated(
            key: const Key('genres-filter-list'),
            scrollDirection: Axis.horizontal,
            itemCount: BrowseGenre.values.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final genre = BrowseGenre.values[index];
              final selected = feed.genre == genre;
              final scheme = Theme.of(context).colorScheme;
              return ChoiceChip(
                key: Key('genre-${genre.name}'),
                label: Text(genre.label),
                selected: selected,
                backgroundColor: scheme.surfaceContainer,
                selectedColor: scheme.primaryContainer,
                checkmarkColor: scheme.onPrimaryContainer,
                labelStyle: TextStyle(
                  color: selected
                      ? scheme.onPrimaryContainer
                      : scheme.onSurface,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
                onSelected: (_) => onSelected(genre),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        if (feed.isGenreLoading)
          const SizedBox(
            height: 156,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (feed.genrePicks.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text('No titles are available for this genre right now.'),
          )
        else
          SizedBox(
            height: 156,
            child: ListView.separated(
              key: const Key('genre-picks-horizontal-list'),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: feed.genrePicks.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) => SizedBox(
                width: cardWidth,
                child: MovieCard(movie: feed.genrePicks[index]),
              ),
            ),
          ),
      ],
    );
  }
}

class _MediaSection extends StatelessWidget {
  const _MediaSection({
    required this.title,
    required this.icon,
    required this.movies,
  });

  final String title;
  final IconData icon;
  final List<Movie> movies;

  @override
  Widget build(BuildContext context) {
    final cardWidth = (MediaQuery.sizeOf(context).width - 56).clamp(
      280.0,
      360.0,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
        const SizedBox(height: 12),
        if (movies.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text('No titles are available right now.'),
          )
        else
          SizedBox(
            height: 156,
            child: ListView.separated(
              key: Key('${title.toLowerCase()}-horizontal-list'),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: movies.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) => SizedBox(
                width: cardWidth,
                child: MovieCard(movie: movies[index]),
              ),
            ),
          ),
      ],
    );
  }
}
