import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/app_providers.dart';
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
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            key: const Key('movie-search-field'),
            controller: _textController,
            onChanged: _onChanged,
            textInputAction: TextInputAction.search,
            onSubmitted: (value) {
              _debounce?.cancel();
              ref.read(searchProvider.notifier).search(value);
            },
            decoration: InputDecoration(
              hintText: 'Search titles',
              prefixIcon: const Icon(Icons.search),
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
                      icon: const Icon(Icons.close),
                    ),
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
      return const StatePanel(
        icon: Icons.manage_search,
        title: 'Find your next movie',
        message: 'Search by an original, translated, or alternative title.',
      );
    }
    return results.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => StatePanel(
        icon: Icons.wifi_off_outlined,
        title: 'Search failed',
        message: readableError(error),
        actionLabel: 'Try again',
        onAction: () => ref.read(searchProvider.notifier).retry(),
      ),
      data: (data) {
        if (data.movies.isEmpty) {
          return StatePanel(
            icon: Icons.search_off,
            title: 'No matches',
            message: 'No movies matched “${search.query}”. Try another title.',
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
}
