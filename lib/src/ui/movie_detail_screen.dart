import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/movie.dart';
import '../state/app_providers.dart';
import 'widgets/movie_poster.dart';

class MovieDetailScreen extends ConsumerStatefulWidget {
  const MovieDetailScreen({required this.movie, super.key});

  final Movie movie;

  @override
  ConsumerState<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends ConsumerState<MovieDetailScreen> {
  late final ScrollController _scrollController;
  bool _showCompactTitle = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  void _onScroll() {
    final shouldShow = _scrollController.offset > 180;
    if (shouldShow != _showCompactTitle) {
      setState(() => _showCompactTitle = shouldShow);
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
    final details = ref.watch(movieDetailsProvider(widget.movie));
    final movie = details.value == null
        ? widget.movie
        : widget.movie.mergeDetails(details.value!);
    final saved = ref.watch(
      watchlistProvider.select(
        (state) => state.value?.contains(movie) ?? false,
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _showCompactTitle
              ? movie.title
              : movie.mediaType == MediaType.tv
              ? 'Series details'
              : 'Movie details',
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          key: const Key('movie-detail-scroll'),
          controller: _scrollController,
          padding: EdgeInsets.only(
            bottom: 24 + MediaQuery.paddingOf(context).bottom,
          ),
          children: <Widget>[
            _Backdrop(movie: movie),
            if (details.isLoading) const LinearProgressIndicator(minHeight: 2),
            if (details.hasError)
              Container(
                color: Theme.of(context).colorScheme.secondaryContainer,
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.cloud_off_outlined),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Showing saved summary. Extra details are unavailable offline.',
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          ref.invalidate(movieDetailsProvider(widget.movie)),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'MOVIE',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    movie.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 14,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      _Metadata(
                        icon: Icons.star_rounded,
                        label: movie.voteAverage.toStringAsFixed(1),
                        iconColor: Colors.amber,
                      ),
                      _Metadata(
                        icon: Icons.calendar_today,
                        label: movie.releaseYear,
                      ),
                      if (movie.runtime != null)
                        _Metadata(
                          icon: Icons.schedule,
                          label: '${movie.runtime} min',
                        ),
                    ],
                  ),
                  if (movie.genres.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: movie.genres
                          .map((genre) => Chip(label: Text(genre)))
                          .toList(growable: false),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () async {
                        try {
                          await ref
                              .read(watchlistProvider.notifier)
                              .toggle(movie);
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
                      icon: Icon(
                        saved ? Icons.bookmark_remove : Icons.bookmark_add,
                      ),
                      label: Text(
                        saved ? 'Remove from watchlist' : 'Add to watchlist',
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Overview',
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(letterSpacing: -.3),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    movie.overview.isEmpty
                        ? 'No overview is available for this title.'
                        : movie.overview,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(height: 1.55),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.movie});

  final Movie movie;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              MoviePoster(url: movie.backdropUrl ?? movie.posterUrl),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[Color(0x11000000), Color(0xB8000000)],
                  ),
                ),
              ),
              Positioned(
                left: 18,
                bottom: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xD91A1A1D),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.star_rounded,
                        color: Color(0xFFFFC44D),
                        size: 17,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${movie.voteAverage.toStringAsFixed(1)} / 10',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Metadata extends StatelessWidget {
  const _Metadata({required this.icon, required this.label, this.iconColor});

  final IconData icon;
  final String label;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            icon,
            size: 17,
            color: iconColor ?? Theme.of(context).colorScheme.secondary,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
