import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/tmdb_client.dart';
import '../repositories/movie_repository.dart';
import '../state/app_providers.dart';
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
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
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
                  hintText: _animatedHint.isEmpty
                      ? _defaultHint(search.category)
                      : 'Try “$_animatedHint”',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _textController.text.isEmpty
                      ? null
                      : IconButton(
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
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Powered by TMDB · Results update as you type',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<SearchCategory>(
              key: const Key('search-category-selector'),
              segments: const <ButtonSegment<SearchCategory>>[
                ButtonSegment(
                  value: SearchCategory.movies,
                  label: Text('Movies'),
                  icon: Icon(Icons.movie_outlined),
                ),
                ButtonSegment(
                  value: SearchCategory.series,
                  label: Text('Series'),
                  icon: Icon(Icons.tv_outlined),
                ),
                ButtonSegment(
                  value: SearchCategory.anime,
                  label: Text('Anime'),
                  icon: Icon(Icons.animation_outlined),
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
        ),
        Expanded(child: _buildResults(search)),
      ],
    );
  }

  Widget _buildResults(SearchState search) {
    final results = search.results;
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
          return StatePanel(
            icon: Icons.search_off,
            title: 'No matches',
            message: search.query.isEmpty
                ? 'No ${_categoryName(search.category, plural: true)} are available right now.'
                : 'No ${_categoryName(search.category, plural: true)} matched “${search.query}”. Try another title.',
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
