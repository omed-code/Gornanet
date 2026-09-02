import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

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
          icon: credentialError ? Symbols.key_off : Symbols.cloud_off,
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
            icon: Symbols.movie_filter,
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
                icon: Symbols.theaters_rounded,
                movies: data.movies,
                autoScrollInterval: const Duration(seconds: 6),
              ),
              const SizedBox(height: 24),
              _MediaSection(
                title: 'Series',
                icon: Symbols.subscriptions_rounded,
                movies: data.series,
                autoScrollInterval: const Duration(seconds: 7),
              ),
              const SizedBox(height: 24),
              _MediaSection(
                title: 'Anime',
                icon: Symbols.auto_awesome_rounded,
                movies: data.anime,
                autoScrollInterval: const Duration(seconds: 8),
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
              Symbols.widgets_rounded,
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
            padding: const EdgeInsets.only(right: 12),
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
          _AutoScrollingMovieCarousel(
            listKey: const Key('genre-picks-horizontal-list'),
            movies: feed.genrePicks,
            cardWidth: cardWidth,
            autoScrollInterval: const Duration(seconds: 5),
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
    required this.autoScrollInterval,
  });

  final String title;
  final IconData icon;
  final List<Movie> movies;
  final Duration autoScrollInterval;

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
          _AutoScrollingMovieCarousel(
            listKey: Key('${title.toLowerCase()}-horizontal-list'),
            movies: movies,
            cardWidth: cardWidth,
            autoScrollInterval: autoScrollInterval,
          ),
      ],
    );
  }
}

class _AutoScrollingMovieCarousel extends StatefulWidget {
  const _AutoScrollingMovieCarousel({
    required this.listKey,
    required this.movies,
    required this.cardWidth,
    required this.autoScrollInterval,
  });

  final Key listKey;
  final List<Movie> movies;
  final double cardWidth;
  final Duration autoScrollInterval;

  @override
  State<_AutoScrollingMovieCarousel> createState() =>
      _AutoScrollingMovieCarouselState();
}

class _AutoScrollingMovieCarouselState
    extends State<_AutoScrollingMovieCarousel> {
  static const _spacing = 12.0;
  late final ScrollController _controller;
  Timer? _timer;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant _AutoScrollingMovieCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.movies != widget.movies ||
        oldWidget.autoScrollInterval != widget.autoScrollInterval) {
      _currentIndex = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.hasClients) _controller.jumpTo(0);
      });
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    if (widget.movies.length < 2) return;
    _timer = Timer.periodic(widget.autoScrollInterval, (_) {
      if (!mounted || !_controller.hasClients) return;
      _currentIndex = (_currentIndex + 1) % widget.movies.length;
      final target = _currentIndex * (widget.cardWidth + _spacing);
      _controller.animateTo(
        target.clamp(0, _controller.position.maxScrollExtent),
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 156,
      child: ListView.separated(
        key: widget.listKey,
        controller: _controller,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(right: 12),
        physics: const BouncingScrollPhysics(),
        itemCount: widget.movies.length,
        separatorBuilder: (_, _) => const SizedBox(width: _spacing),
        itemBuilder: (context, index) => SizedBox(
          width: widget.cardWidth,
          child: MovieCard(movie: widget.movies[index]),
        ),
      ),
    );
  }
}
