import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../core/tmdb_client.dart';
import '../models/movie.dart';
import '../repositories/movie_repository.dart';
import '../state/app_providers.dart';
import 'all_titles_screen.dart';
import 'widgets/credential_dialog.dart';
import 'widgets/movie_card.dart';
import 'widgets/state_panel.dart';

class TrendingScreen extends ConsumerStatefulWidget {
  const TrendingScreen({super.key});

  @override
  ConsumerState<TrendingScreen> createState() => _TrendingScreenState();
}

class _TrendingScreenState extends ConsumerState<TrendingScreen> {
  bool _isInteracting = false;

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification is ScrollStartNotification) {
      _setInteracting(true);
    } else if (notification is ScrollEndNotification) {
      _setInteracting(false);
    }
    return false;
  }

  void _setInteracting(bool value) {
    if (_isInteracting == value) return;
    setState(() => _isInteracting = value);
  }

  @override
  Widget build(BuildContext context) {
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
        return NotificationListener<ScrollNotification>(
          onNotification: _onScrollNotification,
          child: RefreshIndicator(
            onRefresh: ref.read(homeFeedProvider.notifier).refresh,
            child: ListView(
              key: const Key('home-sections-list'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: <Widget>[
                _GenreSection(
                  feed: data,
                  autoScrollEnabled: !_isInteracting,
                  onSelected: ref.read(homeFeedProvider.notifier).selectGenre,
                ),
                const SizedBox(height: 20),
                _MediaSection(
                  title: 'Movies',
                  icon: Symbols.theaters_rounded,
                  movies: data.movies,
                  autoScrollEnabled: !_isInteracting,
                  autoScrollInterval: const Duration(seconds: 6),
                ),
                const SizedBox(height: 20),
                _MediaSection(
                  title: 'Series',
                  icon: Symbols.subscriptions_rounded,
                  movies: data.series,
                  autoScrollEnabled: !_isInteracting,
                  autoScrollInterval: const Duration(seconds: 7),
                ),
                const SizedBox(height: 20),
                _MediaSection(
                  title: 'Anime',
                  icon: Symbols.auto_awesome_rounded,
                  movies: data.anime,
                  autoScrollEnabled: !_isInteracting,
                  autoScrollInterval: const Duration(seconds: 8),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GenreSection extends StatelessWidget {
  const _GenreSection({
    required this.feed,
    required this.autoScrollEnabled,
    required this.onSelected,
  });

  final HomeFeed feed;
  final bool autoScrollEnabled;
  final ValueChanged<BrowseGenre> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _SectionHeader(
          icon: Symbols.widgets_rounded,
          title: 'Genres',
          actionLabel: 'See all',
          onAction: feed.genrePicks.isEmpty
              ? null
              : () => _openAllTitles(
                  context,
                  '${feed.genre.label} titles',
                  feed.genrePicks,
                ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 42,
          child: Stack(
            children: <Widget>[
              ListView.separated(
                key: const Key('genres-filter-list'),
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(right: 24),
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
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    labelPadding: const EdgeInsets.symmetric(horizontal: 3),
                    backgroundColor: scheme.surfaceContainer,
                    selectedColor: scheme.primaryContainer,
                    checkmarkColor: scheme.onPrimaryContainer,
                    labelStyle: TextStyle(
                      color: selected
                          ? scheme.onPrimaryContainer
                          : scheme.onSurface,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      fontSize: 13,
                    ),
                    onSelected: (_) => onSelected(genre),
                  );
                },
              ),
              Positioned(
                top: 0,
                right: 0,
                bottom: 0,
                width: 24,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[
                          Theme.of(
                            context,
                          ).scaffoldBackgroundColor.withValues(alpha: 0),
                          Theme.of(context).scaffoldBackgroundColor,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
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
            autoScrollEnabled: autoScrollEnabled,
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
    required this.autoScrollEnabled,
    required this.autoScrollInterval,
  });

  final String title;
  final IconData icon;
  final List<Movie> movies;
  final bool autoScrollEnabled;
  final Duration autoScrollInterval;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _SectionHeader(
          icon: icon,
          title: title,
          actionLabel: 'See all',
          onAction: movies.isEmpty
              ? null
              : () => _openAllTitles(context, title, movies),
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
            autoScrollEnabled: autoScrollEnabled,
            autoScrollInterval: autoScrollInterval,
          ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: <Widget>[
        Icon(icon, color: scheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        if (onAction != null)
          TextButton.icon(
            onPressed: onAction,
            iconAlignment: IconAlignment.end,
            icon: const Icon(Symbols.arrow_forward_rounded, size: 16),
            label: Text(actionLabel),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              foregroundColor: scheme.secondary,
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
      ],
    );
  }
}

void _openAllTitles(BuildContext context, String title, List<Movie> movies) {
  Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => AllTitlesScreen(title: title, movies: movies),
    ),
  );
}

class _AutoScrollingMovieCarousel extends StatefulWidget {
  const _AutoScrollingMovieCarousel({
    required this.listKey,
    required this.movies,
    required this.autoScrollEnabled,
    required this.autoScrollInterval,
  });

  final Key listKey;
  final List<Movie> movies;
  final bool autoScrollEnabled;
  final Duration autoScrollInterval;

  @override
  State<_AutoScrollingMovieCarousel> createState() =>
      _AutoScrollingMovieCarouselState();
}

class _AutoScrollingMovieCarouselState
    extends State<_AutoScrollingMovieCarousel> {
  static const _spacing = 12.0;
  late PageController _controller;
  Timer? _timer;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant _AutoScrollingMovieCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.movies != widget.movies) {
      _currentIndex = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.hasClients) _controller.jumpToPage(0);
      });
    }
    if (oldWidget.movies != widget.movies ||
        oldWidget.autoScrollEnabled != widget.autoScrollEnabled ||
        oldWidget.autoScrollInterval != widget.autoScrollInterval) {
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    if (!widget.autoScrollEnabled || widget.movies.length < 2) return;
    _timer = Timer.periodic(widget.autoScrollInterval, (_) {
      if (!mounted || !_controller.hasClients) return;
      _currentIndex = (_currentIndex + 1) % widget.movies.length;
      if (_currentIndex == 0) {
        _controller.jumpToPage(0);
      } else {
        _controller.animateToPage(
          _currentIndex,
          duration: const Duration(milliseconds: 520),
          curve: Curves.easeOutCubic,
        );
      }
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
      child: PageView.builder(
        key: widget.listKey,
        controller: _controller,
        scrollDirection: Axis.horizontal,
        padEnds: false,
        physics: const PageScrollPhysics(parent: BouncingScrollPhysics()),
        onPageChanged: (index) => _currentIndex = index,
        itemCount: widget.movies.length,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(right: _spacing),
          child: MovieCard(movie: widget.movies[index]),
        ),
      ),
    );
  }
}
