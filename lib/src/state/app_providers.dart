import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/tmdb_client.dart';
import '../models/movie.dart';
import '../models/movie_page.dart';
import '../repositories/movie_repository.dart';
import '../repositories/preferences_repositories.dart';

const tmdbAccessToken = String.fromEnvironment('TMDB_ACCESS_TOKEN');
const tmdbApiKey = String.fromEnvironment('TMDB_API_KEY');

final tmdbClientProvider = Provider<TmdbClient>((ref) {
  final client = TmdbClient(accessToken: tmdbAccessToken, apiKey: tmdbApiKey);
  ref.onDispose(client.close);
  return client;
});

final movieRepositoryProvider = Provider<MovieRepository>(
  (ref) => TmdbMovieRepository(ref.watch(tmdbClientProvider)),
);

final preferencesStoreProvider = Provider<PreferencesStore>(
  (ref) => SharedPreferencesStore(),
);

final watchlistRepositoryProvider = Provider<WatchlistRepository>(
  (ref) => LocalWatchlistRepository(ref.watch(preferencesStoreProvider)),
);

final themeRepositoryProvider = Provider<ThemeRepository>(
  (ref) => LocalThemeRepository(ref.watch(preferencesStoreProvider)),
);

class PagedMovies {
  const PagedMovies({
    required this.movies,
    required this.page,
    required this.totalPages,
    this.isLoadingMore = false,
    this.loadMoreError,
  });

  factory PagedMovies.fromPage(MoviePage page) => PagedMovies(
    movies: page.movies,
    page: page.page,
    totalPages: page.totalPages,
  );

  final List<Movie> movies;
  final int page;
  final int totalPages;
  final bool isLoadingMore;
  final String? loadMoreError;

  bool get canLoadMore => page < totalPages;

  PagedMovies copyWith({
    List<Movie>? movies,
    int? page,
    int? totalPages,
    bool? isLoadingMore,
    String? loadMoreError,
    bool clearLoadMoreError = false,
  }) => PagedMovies(
    movies: movies ?? this.movies,
    page: page ?? this.page,
    totalPages: totalPages ?? this.totalPages,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    loadMoreError: clearLoadMoreError
        ? null
        : loadMoreError ?? this.loadMoreError,
  );

  PagedMovies append(MoviePage next) {
    final byId = <int, Movie>{for (final movie in movies) movie.id: movie};
    for (final movie in next.movies) {
      byId[movie.id] = movie;
    }
    return PagedMovies(
      movies: byId.values.toList(growable: false),
      page: next.page,
      totalPages: next.totalPages,
    );
  }
}

String readableError(Object error) => switch (error) {
  AppException(:final message) => message,
  _ => 'Something went wrong. Please try again.',
};

final trendingProvider = AsyncNotifierProvider<TrendingNotifier, PagedMovies>(
  TrendingNotifier.new,
);

class TrendingNotifier extends AsyncNotifier<PagedMovies> {
  @override
  Future<PagedMovies> build() async {
    final page = await ref.watch(movieRepositoryProvider).trending(page: 1);
    return PagedMovies.fromPage(page);
  }

  Future<void> refresh() async {
    state = const AsyncLoading<PagedMovies>();
    state = await AsyncValue.guard(() async {
      final page = await ref.read(movieRepositoryProvider).trending(page: 1);
      return PagedMovies.fromPage(page);
    });
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || current.isLoadingMore || !current.canLoadMore) {
      return;
    }
    state = AsyncData(
      current.copyWith(isLoadingMore: true, clearLoadMoreError: true),
    );
    try {
      final page = await ref
          .read(movieRepositoryProvider)
          .trending(page: current.page + 1);
      state = AsyncData(current.append(page));
    } catch (error) {
      state = AsyncData(
        current.copyWith(
          isLoadingMore: false,
          loadMoreError: readableError(error),
        ),
      );
    }
  }
}

class SearchState {
  const SearchState({this.query = '', this.results});

  final String query;
  final AsyncValue<PagedMovies>? results;

  SearchState copyWith({String? query, AsyncValue<PagedMovies>? results}) =>
      SearchState(query: query ?? this.query, results: results ?? this.results);
}

final searchProvider = NotifierProvider<SearchNotifier, SearchState>(
  SearchNotifier.new,
);

class SearchNotifier extends Notifier<SearchState> {
  int _requestId = 0;

  @override
  SearchState build() => const SearchState();

  Future<void> search(String rawQuery) async {
    final query = rawQuery.trim();
    final requestId = ++_requestId;
    if (query.isEmpty) {
      state = const SearchState();
      return;
    }

    state = SearchState(query: query, results: const AsyncLoading());
    try {
      final page = await ref
          .read(movieRepositoryProvider)
          .search(query: query, page: 1);
      if (requestId == _requestId) {
        state = SearchState(
          query: query,
          results: AsyncData(PagedMovies.fromPage(page)),
        );
      }
    } catch (error, stackTrace) {
      if (requestId == _requestId) {
        state = SearchState(
          query: query,
          results: AsyncError(error, stackTrace),
        );
      }
    }
  }

  Future<void> retry() => search(state.query);

  Future<void> loadMore() async {
    final query = state.query;
    final current = state.results?.value;
    if (current == null || current.isLoadingMore || !current.canLoadMore) {
      return;
    }
    final requestId = _requestId;
    state = state.copyWith(
      results: AsyncData(
        current.copyWith(isLoadingMore: true, clearLoadMoreError: true),
      ),
    );
    try {
      final page = await ref
          .read(movieRepositoryProvider)
          .search(query: query, page: current.page + 1);
      if (requestId == _requestId) {
        state = state.copyWith(results: AsyncData(current.append(page)));
      }
    } catch (error) {
      if (requestId == _requestId) {
        state = state.copyWith(
          results: AsyncData(
            current.copyWith(
              isLoadingMore: false,
              loadMoreError: readableError(error),
            ),
          ),
        );
      }
    }
  }
}

final watchlistProvider = AsyncNotifierProvider<WatchlistNotifier, List<Movie>>(
  WatchlistNotifier.new,
);

class WatchlistNotifier extends AsyncNotifier<List<Movie>> {
  @override
  Future<List<Movie>> build() => ref.watch(watchlistRepositoryProvider).load();

  bool contains(int movieId) =>
      state.value?.any((movie) => movie.id == movieId) ?? false;

  Future<void> toggle(Movie movie) async {
    final previous = state.value ?? const <Movie>[];
    final updated = previous.any((item) => item.id == movie.id)
        ? previous.where((item) => item.id != movie.id).toList(growable: false)
        : <Movie>[movie, ...previous];
    state = AsyncData(updated);
    try {
      await ref.read(watchlistRepositoryProvider).save(updated);
    } catch (error, stackTrace) {
      state = AsyncData(previous);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}

final themeModeProvider = AsyncNotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

class ThemeModeNotifier extends AsyncNotifier<ThemeMode> {
  @override
  Future<ThemeMode> build() => ref.watch(themeRepositoryProvider).load();

  Future<void> setMode(ThemeMode mode) async {
    final previous = state.value ?? ThemeMode.system;
    state = AsyncData(mode);
    try {
      await ref.read(themeRepositoryProvider).save(mode);
    } catch (error, stackTrace) {
      state = AsyncData(previous);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}

final movieDetailsProvider = FutureProvider.autoDispose.family<Movie, int>(
  (ref, movieId) => ref.watch(movieRepositoryProvider).details(movieId),
);
