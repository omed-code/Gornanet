import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/tmdb_client.dart';
import '../models/movie.dart';
import '../models/movie_page.dart';
import '../repositories/movie_repository.dart';
import '../repositories/preferences_repositories.dart';

const tmdbAccessToken = String.fromEnvironment('TMDB_ACCESS_TOKEN');
const tmdbApiKey = String.fromEnvironment('TMDB_API_KEY');

final credentialRepositoryProvider = Provider<CredentialRepository>(
  (ref) => SecureCredentialRepository(),
);

<<<<<<< HEAD
final tmdbCredentialProvider = NotifierProvider<TmdbCredentialNotifier, String>(
  TmdbCredentialNotifier.new,
);

class TmdbCredentialNotifier extends Notifier<String> {
  String get _compileTimeCredential {
    if (tmdbApiKey.trim().isNotEmpty) return tmdbApiKey.trim();
    if (tmdbAccessToken.trim().isNotEmpty) return tmdbAccessToken.trim();
    return '';
  }

  @override
  String build() {
    Future<void>(_restoreStoredCredential);
    return _compileTimeCredential;
  }

  Future<void> _restoreStoredCredential() async {
    try {
      final stored = await ref
          .read(credentialRepositoryProvider)
          .load()
          .timeout(const Duration(seconds: 2));
      if (ref.mounted && stored?.trim().isNotEmpty == true) {
        state = stored!.trim();
      }
    } catch (_) {
      // Startup must remain usable when platform secure storage is unavailable.
    }
=======
final tmdbCredentialProvider =
    AsyncNotifierProvider<TmdbCredentialNotifier, String?>(
      TmdbCredentialNotifier.new,
    );

class TmdbCredentialNotifier extends AsyncNotifier<String?> {
  String? get _compileTimeCredential {
    if (tmdbApiKey.trim().isNotEmpty) return tmdbApiKey.trim();
    if (tmdbAccessToken.trim().isNotEmpty) return tmdbAccessToken.trim();
    return null;
  }

  @override
  Future<String?> build() async {
    final stored = await ref.watch(credentialRepositoryProvider).load();
    return stored?.trim().isNotEmpty == true
        ? stored!.trim()
        : _compileTimeCredential;
>>>>>>> 14ce313 (new desing)
  }

  Future<void> save(String rawCredential) async {
    final credential = rawCredential.trim().replaceFirst(
      RegExp(r'^Bearer\s+', caseSensitive: false),
      '',
    );
<<<<<<< HEAD
    await ref
        .read(credentialRepositoryProvider)
        .save(credential)
        .timeout(const Duration(seconds: 5));
    state = credential;
  }

  Future<void> clear() async {
    await ref
        .read(credentialRepositoryProvider)
        .clear()
        .timeout(const Duration(seconds: 5));
    state = _compileTimeCredential;
=======
    await ref.read(credentialRepositoryProvider).save(credential);
    state = AsyncData(credential);
  }

  Future<void> clear() async {
    await ref.read(credentialRepositoryProvider).clear();
    state = AsyncData(_compileTimeCredential);
>>>>>>> 14ce313 (new desing)
  }
}

final tmdbClientProvider = Provider<TmdbClient>((ref) {
<<<<<<< HEAD
  final credential = ref.watch(tmdbCredentialProvider);
=======
  final credential = ref.watch(tmdbCredentialProvider).value ?? '';
>>>>>>> 14ce313 (new desing)
  final client = TmdbClient(accessToken: credential);
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
    final byId = <String, Movie>{
      for (final movie in movies) movie.identityKey: movie,
    };
    for (final movie in next.movies) {
      byId[movie.identityKey] = movie;
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
  retry: (retryCount, error) => null,
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
  const SearchState({
    this.query = '',
    this.category = SearchCategory.movies,
    this.results,
  });

  final String query;
  final SearchCategory category;
  final AsyncValue<PagedMovies>? results;

  SearchState copyWith({
    String? query,
    SearchCategory? category,
    AsyncValue<PagedMovies>? results,
  }) => SearchState(
    query: query ?? this.query,
    category: category ?? this.category,
    results: results ?? this.results,
  );
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
    final category = state.category;
    final requestId = ++_requestId;
    if (query.isEmpty) {
      state = SearchState(category: category);
      return;
    }

    state = SearchState(
      query: query,
      category: category,
      results: const AsyncLoading(),
    );
    try {
      final page = await ref
          .read(movieRepositoryProvider)
          .search(query: query, page: 1, category: category);
      if (requestId == _requestId) {
        state = SearchState(
          query: query,
          category: category,
          results: AsyncData(PagedMovies.fromPage(page)),
        );
      }
    } catch (error, stackTrace) {
      if (requestId == _requestId) {
        state = SearchState(
          query: query,
          category: category,
          results: AsyncError(error, stackTrace),
        );
      }
    }
  }

  Future<void> selectCategory(SearchCategory category) async {
    if (category == state.category) return;
    final query = state.query;
    state = SearchState(query: query, category: category);
    if (query.isNotEmpty) await search(query);
  }

  Future<void> retry() => search(state.query);

  Future<void> loadMore() async {
    final query = state.query;
    final category = state.category;
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
          .search(query: query, page: current.page + 1, category: category);
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

  bool contains(Movie movie) => state.value?.contains(movie) ?? false;

  Future<void> toggle(Movie movie) async {
    final previous = state.value ?? const <Movie>[];
    final updated = previous.contains(movie)
        ? previous.where((item) => item != movie).toList(growable: false)
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

final movieDetailsProvider = FutureProvider.autoDispose.family<Movie, Movie>(
  (ref, movie) => ref
      .watch(movieRepositoryProvider)
      .details(movie.id, mediaType: movie.mediaType),
);
