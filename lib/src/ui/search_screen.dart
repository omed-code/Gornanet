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
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _textController;
  late final ScrollController _scrollController;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _scrollController = ScrollController()..addListener(_onScroll);
    Future<void>.microtask(() => ref.read(searchProvider.notifier).browse());
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 450),
      () => ref.read(searchProvider.notifier).search(value),
    );
    setState(() {});
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 500) {
      ref.read(searchProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
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
                onChanged: _onChanged,
                textInputAction: TextInputAction.search,
                onSubmitted: (value) {
                  _debounce?.cancel();
                  ref.read(searchProvider.notifier).search(value);
                },
                decoration: InputDecoration(
                  hintText: 'Search movies, titles, and stories',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _textController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            _debounce?.cancel();
                            _textController.clear();
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
}
