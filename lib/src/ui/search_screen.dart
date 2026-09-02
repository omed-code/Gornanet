import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/tmdb_client.dart';
import '../repositories/movie_repository.dart';
import '../models/search_filters.dart';
import '../state/app_providers.dart';
import 'movie_detail_screen.dart';
import 'widgets/credential_dialog.dart';
import 'widgets/movie_list_view.dart';
import 'widgets/state_panel.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({this.isActive = true, super.key});

  final bool isActive;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  static const _hintTitles = <SearchCategory, List<String>>{
    SearchCategory.movies: <String>['Dune', 'Inception', 'Interstellar'],
    SearchCategory.series: <String>['Breaking Bad', 'Dark', 'The Last of Us'],
    SearchCategory.anime: <String>[
      'Attack on Titan',
      'Death Note',
      'Demon Slayer',
    ],
  };

  late final TextEditingController _textController;
  late final ScrollController _scrollController;
  late final FocusNode _searchFocusNode;
  Timer? _debounce;
  Timer? _hintTimer;
  SearchCategory _hintCategory = SearchCategory.movies;
  String _animatedHint = '';
  int _hintTitleIndex = 0;
  int _hintCharacterCount = 0;
  int _hintPauseTicks = 0;
  bool _deletingHint = false;
  bool _loadingRandomSuggestion = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _scrollController = ScrollController()..addListener(_onScroll);
    _searchFocusNode = FocusNode();
    Future<void>.microtask(() => ref.read(searchProvider.notifier).browse());
    if (widget.isActive) {
      _startHintAnimation(_hintCategory);
      _focusSearchField();
    }
  }

  @override
  void didUpdateWidget(covariant SearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) {
      _startHintAnimation(_hintCategory);
      _focusSearchField();
    } else if (oldWidget.isActive && !widget.isActive) {
      _hintTimer?.cancel();
      _hintTimer = null;
    }
  }

  void _focusSearchField() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.isActive) _searchFocusNode.requestFocus();
    });
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.isEmpty) {
      if (widget.isActive && _hintTimer == null) {
        _startHintAnimation(_hintCategory);
      }
    } else {
      _hintTimer?.cancel();
      _hintTimer = null;
    }
    _debounce = Timer(
      const Duration(milliseconds: 450),
      () => ref.read(searchProvider.notifier).search(value),
    );
    setState(() {});
  }

  void _startHintAnimation(SearchCategory category) {
    _hintTimer?.cancel();
    _hintCategory = category;
    _hintTitleIndex = 0;
    _hintCharacterCount = 0;
    _hintPauseTicks = 2;
    _deletingHint = false;
    _animatedHint = '';
    if (!widget.isActive || _textController.text.isNotEmpty) {
      _hintTimer = null;
      return;
    }

    _hintTimer = Timer.periodic(const Duration(milliseconds: 85), (timer) {
      if (!mounted || !widget.isActive || _textController.text.isNotEmpty) {
        timer.cancel();
        _hintTimer = null;
        return;
      }
      if (_hintPauseTicks > 0) {
        _hintPauseTicks--;
        return;
      }

      final titles = _hintTitles[category]!;
      final title = titles[_hintTitleIndex];
      if (!_deletingHint) {
        _hintCharacterCount++;
        if (_hintCharacterCount == title.length) {
          if (_hintTitleIndex == titles.length - 1) {
            timer.cancel();
            _hintTimer = null;
          } else {
            _hintPauseTicks = 12;
            _deletingHint = true;
          }
        }
      } else {
        _hintCharacterCount--;
        if (_hintCharacterCount == 0) {
          _hintTitleIndex++;
          _deletingHint = false;
          _hintPauseTicks = 3;
        }
      }
      setState(() {
        _animatedHint = title.substring(0, _hintCharacterCount);
      });
    });
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 500) {
      ref.read(searchProvider.notifier).loadMore();
    }
  }

  Future<void> _showRandomSuggestion() async {
    if (_loadingRandomSuggestion) return;
    setState(() => _loadingRandomSuggestion = true);
    try {
      final movie = await ref.read(searchProvider.notifier).randomSuggestion();
      if (mounted) {
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => MovieDetailScreen(movie: movie),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(readableError(error))));
      }
    } finally {
      if (mounted) setState(() => _loadingRandomSuggestion = false);
    }
  }

  Future<void> _showFilters(SearchFilters filters) async {
    final updated = await showModalBottomSheet<SearchFilters>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _SearchFilterSheet(initialFilters: filters),
    );
    if (updated != null && mounted) {
      await ref.read(searchProvider.notifier).applyFilters(updated);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _hintTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchFocusNode.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final search = ref.watch(searchProvider);
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: _buildDiscoveryPanel(context, search),
        ),
        Expanded(child: _buildResults(search)),
      ],
    );
  }

  Widget _buildDiscoveryPanel(BuildContext context, SearchState search) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: scheme.shadow.withValues(alpha: .055),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
            child: Row(
              children: <Widget>[
                Icon(Icons.explore_rounded, size: 18, color: scheme.primary),
                const SizedBox(width: 7),
                Text(
                  'DISCOVER',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                const Spacer(),
                if (search.filters.activeCount > 0)
                  Text(
                    '${search.filters.activeCount} active',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.secondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
          TextField(
            key: const Key('movie-search-field'),
            controller: _textController,
            focusNode: _searchFocusNode,
            onChanged: _onChanged,
            textInputAction: TextInputAction.search,
            onSubmitted: (value) {
              _debounce?.cancel();
              ref.read(searchProvider.notifier).search(value);
            },
            decoration: InputDecoration(
              filled: true,
              fillColor: scheme.surfaceContainer,
              hintText: _animatedHint.isEmpty
                  ? _defaultHint(search.category)
                  : 'Try “$_animatedHint”',
              prefixIcon: Icon(Icons.search_rounded, color: scheme.secondary),
              suffixIconConstraints: const BoxConstraints(minWidth: 52),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (_textController.text.isNotEmpty)
                    IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        _debounce?.cancel();
                        _textController.clear();
                        _startHintAnimation(search.category);
                        ref.read(searchProvider.notifier).search('');
                        setState(() {});
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
                  IconButton.filledTonal(
                    key: const Key('search-filter-button'),
                    tooltip: 'Filter titles',
                    onPressed: () => _showFilters(search.filters),
                    icon: Badge(
                      isLabelVisible: search.filters.activeCount > 0,
                      label: Text('${search.filters.activeCount}'),
                      child: const Icon(Icons.tune_rounded),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              'Search movies, series, and anime from one place',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<SearchCategory>(
              key: const Key('search-category-selector'),
              segments: const <ButtonSegment<SearchCategory>>[
                ButtonSegment(
                  value: SearchCategory.movies,
                  label: Text('Movies'),
                  icon: Icon(Icons.theaters_rounded),
                ),
                ButtonSegment(
                  value: SearchCategory.series,
                  label: Text('Series'),
                  icon: Icon(Icons.subscriptions_rounded),
                ),
                ButtonSegment(
                  value: SearchCategory.anime,
                  label: Text('Anime'),
                  icon: Icon(Icons.auto_awesome_rounded),
                ),
              ],
              selected: <SearchCategory>{search.category},
              showSelectedIcon: false,
              onSelectionChanged: (selection) {
                _debounce?.cancel();
                _startHintAnimation(selection.first);
                ref
                    .read(searchProvider.notifier)
                    .selectCategory(selection.first);
              },
            ),
          ),
          const SizedBox(height: 10),
          Material(
            color: scheme.secondaryContainer,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              key: const Key('random-suggestion-button'),
              borderRadius: BorderRadius.circular(16),
              onTap: _loadingRandomSuggestion ? null : _showRandomSuggestion,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                child: Row(
                  children: <Widget>[
                    if (_loadingRandomSuggestion)
                      const SizedBox.square(
                        dimension: 34,
                        child: Padding(
                          padding: EdgeInsets.all(7),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          'assets/branding/spider_movie_icon.png',
                          key: const Key('random-suggestion-logo'),
                          width: 34,
                          height: 34,
                          fit: BoxFit.cover,
                        ),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            _loadingRandomSuggestion
                                ? 'Finding your next title…'
                                : 'Surprise me',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: scheme.onSecondaryContainer,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          if (!_loadingRandomSuggestion)
                            Text(
                              'Get a random recommendation',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: scheme.onSecondaryContainer
                                        .withValues(alpha: .76),
                                  ),
                            ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: scheme.onSecondaryContainer,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(SearchState search) {
    final results = search.visibleResults;
    if (results == null) {
      return StatePanel(
        icon: Icons.manage_search,
        title: 'Find your next ${_categoryName(search.category)}',
        message: 'Search by an original, translated, or alternative title.',
      );
    }
    return results.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) {
        final credentialError =
            error is AppException &&
            (error.type == AppErrorType.configuration ||
                error.type == AppErrorType.unauthorized);
        return StatePanel(
          icon: credentialError
              ? Icons.key_off_outlined
              : Icons.wifi_off_outlined,
          title: credentialError ? 'TMDB setup required' : 'Search failed',
          message: readableError(error),
          actionLabel: credentialError ? 'Add credential' : 'Try again',
          onAction: credentialError
              ? () => showTmdbCredentialDialog(context, ref)
              : () => ref.read(searchProvider.notifier).retry(),
        );
      },
      data: (data) {
        if (data.movies.isEmpty) {
          final hasFilters = search.filters.activeCount > 0;
          return StatePanel(
            icon: Icons.search_off,
            title: 'No matches',
            message: hasFilters
                ? 'No titles in the loaded results match these filters.'
                : search.query.isEmpty
                ? 'No ${_categoryName(search.category, plural: true)} are available right now.'
                : 'No ${_categoryName(search.category, plural: true)} matched “${search.query}”. Try another title.',
            actionLabel: hasFilters ? 'Clear filters' : null,
            onAction: hasFilters
                ? () {
                    ref
                        .read(searchProvider.notifier)
                        .applyFilters(const SearchFilters());
                  }
                : null,
          );
        }
        return MovieListView(
          data: data,
          controller: _scrollController,
          onRefresh: () => ref.read(searchProvider.notifier).retry(),
          onLoadMoreRetry: () => ref.read(searchProvider.notifier).loadMore(),
        );
      },
    );
  }

  String _categoryName(SearchCategory category, {bool plural = false}) =>
      switch (category) {
        SearchCategory.movies => plural ? 'movies' : 'movie',
        SearchCategory.series => 'series',
        SearchCategory.anime => 'anime',
      };

  String _defaultHint(SearchCategory category) => switch (category) {
    SearchCategory.movies => 'Search movies and stories',
    SearchCategory.series => 'Search series and shows',
    SearchCategory.anime => 'Search anime titles',
  };
}

class _SearchFilterSheet extends StatefulWidget {
  const _SearchFilterSheet({required this.initialFilters});

  final SearchFilters initialFilters;

  @override
  State<_SearchFilterSheet> createState() => _SearchFilterSheetState();
}

class _SearchFilterSheetState extends State<_SearchFilterSheet> {
  static const _genres = <int, String>{
    28: 'Action',
    12: 'Adventure',
    16: 'Animation',
    35: 'Comedy',
    80: 'Crime',
    99: 'Documentary',
    18: 'Drama',
    14: 'Fantasy',
    27: 'Horror',
    10749: 'Romance',
    878: 'Sci-Fi',
    53: 'Thriller',
  };

  late int? _releaseYear;
  late double _minimumRating;
  late Set<int> _genreIds;
  late SearchArtworkQuality _quality;
  late SearchAgeRating _ageRating;

  @override
  void initState() {
    super.initState();
    final filters = widget.initialFilters;
    _releaseYear = filters.releaseYear;
    _minimumRating = filters.minimumRating;
    _genreIds = {...filters.genreIds};
    _quality = filters.quality;
    _ageRating = filters.ageRating;
  }

  SearchFilters get _filters => SearchFilters(
    releaseYear: _releaseYear,
    minimumRating: _minimumRating,
    genreIds: _genreIds,
    quality: _quality,
    ageRating: _ageRating,
  );

  Future<void> _pickReleaseYear() async {
    final year = await showModalBottomSheet<int>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _ReleaseYearPicker(initialYear: _releaseYear),
    );
    if (year != null && mounted) setState(() => _releaseYear = year);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Filter titles',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                TextButton(
                  key: const Key('reset-search-filters'),
                  onPressed: () => setState(() {
                    _releaseYear = null;
                    _minimumRating = 0;
                    _genreIds = <int>{};
                    _quality = SearchArtworkQuality.any;
                    _ageRating = SearchAgeRating.any;
                  }),
                  child: const Text('Reset'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Released year',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const Key('release-year-filter'),
                onPressed: _pickReleaseYear,
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  minimumSize: const Size.fromHeight(56),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                icon: const Icon(Icons.calendar_month_outlined),
                label: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        _releaseYear?.toString() ?? 'Any year',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                    const Icon(Icons.expand_more_rounded),
                  ],
                ),
              ),
            ),
            if (_releaseYear != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => setState(() => _releaseYear = null),
                  child: const Text('Any year'),
                ),
              ),
            const SizedBox(height: 14),
            Text(
              _minimumRating == 0
                  ? 'Rating · Any'
                  : 'Rating · ${_minimumRating.toStringAsFixed(1)} or higher',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Slider(
              key: const Key('rating-filter'),
              value: _minimumRating,
              min: 0,
              max: 10,
              divisions: 20,
              label: _minimumRating.toStringAsFixed(1),
              onChanged: (value) => setState(() => _minimumRating = value),
            ),
            const SizedBox(height: 8),
            Text('Genres', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _genres.entries
                  .map((genre) {
                    final selected = _genreIds.contains(genre.key);
                    return FilterChip(
                      key: Key('search-genre-${genre.key}'),
                      label: Text(genre.value),
                      selected: selected,
                      onSelected: (value) => setState(() {
                        if (value) {
                          _genreIds.add(genre.key);
                        } else {
                          _genreIds.remove(genre.key);
                        }
                      }),
                    );
                  })
                  .toList(growable: false),
            ),
            const SizedBox(height: 20),
            Text('Quality', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<SearchArtworkQuality>(
              key: const Key('quality-filter'),
              segments: const <ButtonSegment<SearchArtworkQuality>>[
                ButtonSegment(
                  value: SearchArtworkQuality.any,
                  label: Text('Any'),
                ),
                ButtonSegment(
                  value: SearchArtworkQuality.poster,
                  label: Text('Poster'),
                ),
                ButtonSegment(
                  value: SearchArtworkQuality.backdrop,
                  label: Text('Backdrop'),
                ),
              ],
              selected: <SearchArtworkQuality>{_quality},
              showSelectedIcon: false,
              onSelectionChanged: (value) =>
                  setState(() => _quality = value.first),
            ),
            const SizedBox(height: 20),
            Text('Age rating', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<SearchAgeRating>(
              key: const Key('age-rating-filter'),
              segments: const <ButtonSegment<SearchAgeRating>>[
                ButtonSegment(value: SearchAgeRating.any, label: Text('Any')),
                ButtonSegment(
                  value: SearchAgeRating.allAges,
                  label: Text('All ages'),
                ),
                ButtonSegment(
                  value: SearchAgeRating.adultsOnly,
                  label: Text('18+'),
                ),
              ],
              selected: <SearchAgeRating>{_ageRating},
              showSelectedIcon: false,
              onSelectionChanged: (value) =>
                  setState(() => _ageRating = value.first),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('apply-search-filters'),
                onPressed: () => Navigator.pop(context, _filters),
                icon: const Icon(Icons.tune_rounded),
                label: Text(
                  _filters.activeCount == 0
                      ? 'Show all titles'
                      : 'Apply ${_filters.activeCount} filters',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReleaseYearPicker extends StatefulWidget {
  const _ReleaseYearPicker({required this.initialYear});

  final int? initialYear;

  @override
  State<_ReleaseYearPicker> createState() => _ReleaseYearPickerState();
}

class _ReleaseYearPickerState extends State<_ReleaseYearPicker> {
  static const _oldestYear = 1950;
  late final int _currentYear;
  late final FixedExtentScrollController _controller;
  late int _selectedYear;

  @override
  void initState() {
    super.initState();
    _currentYear = DateTime.now().year;
    _selectedYear = (widget.initialYear ?? _currentYear).clamp(
      _oldestYear,
      _currentYear,
    );
    _controller = FixedExtentScrollController(
      initialItem: _currentYear - _selectedYear,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final yearCount = _currentYear - _oldestYear + 1;
    return SizedBox(
      height: 340,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          children: <Widget>[
            Text(
              'Choose release year',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListWheelScrollView.useDelegate(
                key: const Key('release-year-wheel'),
                controller: _controller,
                itemExtent: 48,
                diameterRatio: 1.35,
                physics: const FixedExtentScrollPhysics(),
                onSelectedItemChanged: (index) =>
                    _selectedYear = _currentYear - index,
                childDelegate: ListWheelChildBuilderDelegate(
                  childCount: yearCount,
                  builder: (context, index) {
                    final year = _currentYear - index;
                    return Center(
                      child: Text(
                        '$year',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    key: const Key('confirm-release-year'),
                    onPressed: () => Navigator.pop(context, _selectedYear),
                    child: const Text('Select year'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
