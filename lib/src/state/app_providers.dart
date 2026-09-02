import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/tmdb_client.dart';
import '../models/movie.dart';
import '../models/movie_page.dart';
import '../models/search_filters.dart';
import '../repositories/movie_repository.dart';
import '../repositories/preferences_repositories.dart';

const tmdbAccessToken = String.fromEnvironment('TMDB_ACCESS_TOKEN');
const tmdbApiKey = String.fromEnvironment('TMDB_API_KEY');

final credentialRepositoryProvider = Provider<CredentialRepository>(
  (ref) => SecureCredentialRepository(),
);

final tmdbCredentialProvider = NotifierProvider<TmdbCredentialNotifier, String>(
  TmdbCredentialNotifier.new,
);

class TmdbCredentialNotifier extends Notifier<String> {
  final Completer<void> _ready = Completer<void>();

  Future<void> get ready => _ready.future;

  String get _compileTimeCredential {
    if (tmdbApiKey.trim().isNotEmpty) return tmdbApiKey.trim();
    if (tmdbAccessToken.trim().isNotEmpty) return tmdbAccessToken.trim();
    return '';
  }

  @override
  String build() {
    final initialCredential = _compileTimeCredential;
    if (initialCredential.isNotEmpty && !_ready.isCompleted) {
      _ready.complete();
    }
    Future<void>(_restoreStoredCredential);
    return initialCredential;
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
    } finally {
      if (!_ready.isCompleted) _ready.complete();
    }
  }

  Future<void> save(String rawCredential) async {
    final credential = rawCredential.trim().replaceFirst(
      RegExp(r'^Bearer\s+', caseSensitive: false),
      '',
    );
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
  }
}

final tmdbClientProvider = Provider<TmdbClient>((ref) {
  final credential = ref.watch(tmdbCredentialProvider);
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
    await ref.read(tmdbCredentialProvider.notifier).ready;
    final page = await ref.watch(movieRepositoryProvider).trending(page: 1);
    return PagedMovies.fromPage(page);
  }

  Future<void> refresh() async {
    state = const AsyncLoading<PagedMovies>();
    state = await AsyncValue.guard(() async {
      await ref.read(tmdbCredentialProvider.notifier).ready;
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

class HomeFeed {
  const HomeFeed({
    required this.movies,
    required this.series,
    required this.anime,
    required this.genre,
    required this.genrePicks,
    this.isGenreLoading = false,
  });

  final List<Movie> movies;
  final List<Movie> series;
  final List<Movie> anime;
  final BrowseGenre genre;
  final List<Movie> genrePicks;
  final bool isGenreLoading;

  HomeFeed copyWith({
    BrowseGenre? genre,
    List<Movie>? genrePicks,
    bool? isGenreLoading,
  }) => HomeFeed(
    movies: movies,
    series: series,
    anime: anime,
    genre: genre ?? this.genre,
    genrePicks: genrePicks ?? this.genrePicks,
    isGenreLoading: isGenreLoading ?? this.isGenreLoading,
  );
}

final homeFeedProvider = AsyncNotifierProvider<HomeFeedNotifier, HomeFeed>(
  HomeFeedNotifier.new,
  retry: (retryCount, error) => null,
);

class HomeFeedNotifier extends AsyncNotifier<HomeFeed> {
  @override
  Future<HomeFeed> build() => _load(watchRepository: true);

  Future<HomeFeed> _load({required bool watchRepository}) async {
    await ref.read(tmdbCredentialProvider.notifier).ready;
    final repository = watchRepository
        ? ref.watch(movieRepositoryProvider)
        : ref.read(movieRepositoryProvider);
    final pages = await Future.wait<MoviePage>(<Future<MoviePage>>[
      repository.trending(page: 1),
      repository.browse(page: 1, category: SearchCategory.series),
      repository.browse(page: 1, category: SearchCategory.anime),
      repository.browseGenre(genre: BrowseGenre.action, page: 1),
    ]);
    return HomeFeed(
      movies: pages[0].movies.take(5).toList(growable: false),
      series: pages[1].movies.take(5).toList(growable: false),
      anime: pages[2].movies.take(5).toList(growable: false),
      genre: BrowseGenre.action,
      genrePicks: pages[3].movies.take(5).toList(growable: false),
    );
  }

  Future<void> selectGenre(BrowseGenre genre) async {
    final current = state.value;
    if (current == null || current.genre == genre || current.isGenreLoading) {
      return;
    }
    state = AsyncData(current.copyWith(genre: genre, isGenreLoading: true));
    try {
      final page = await ref
          .read(movieRepositoryProvider)
          .browseGenre(genre: genre, page: 1);
      state = AsyncData(
        current.copyWith(
          genre: genre,
          genrePicks: page.movies.take(5).toList(growable: false),
          isGenreLoading: false,
        ),
      );
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading<HomeFeed>();
    state = await AsyncValue.guard(() => _load(watchRepository: false));
  }
}

class SearchState {
  const SearchState({
    this.query = '',
    this.category = SearchCategory.movies,
    this.filters = const SearchFilters(),
    this.results,
  });

  final String query;
  final SearchCategory category;
  final SearchFilters filters;
  final AsyncValue<PagedMovies>? results;

  AsyncValue<PagedMovies>? get visibleResults => results?.whenData(
    (data) => data.copyWith(
      movies: data.movies.where(filters.matches).toList(growable: false),
    ),
  );

  SearchState copyWith({
    String? query,
    SearchCategory? category,
    SearchFilters? filters,
    AsyncValue<PagedMovies>? results,
  }) => SearchState(
    query: query ?? this.query,
    category: category ?? this.category,
    filters: filters ?? this.filters,
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

  Future<void> applyFilters(SearchFilters filters) async {
    state = state.copyWith(filters: filters);
    if (state.query.isEmpty) {
      await browse();
    } else {
      await search(state.query);
    }
  }

  Future<Movie> randomSuggestion() async {
    await ref.read(tmdbCredentialProvider.notifier).ready;
    return ref.read(movieRepositoryProvider).randomSuggestion();
  }

  Future<void> browse() async {
    final category = state.category;
    final filters = state.filters;
    final requestId = ++_requestId;
    state = SearchState(
      category: category,
      filters: filters,
      results: const AsyncLoading(),
    );
    try {
      await ref.read(tmdbCredentialProvider.notifier).ready;
      final repository = ref.read(movieRepositoryProvider);
      final page = await _firstMatchingPage(
        (page) =>
            repository.browse(page: page, category: category, filters: filters),
      );
      if (requestId == _requestId) {
        state = SearchState(
          category: category,
          filters: filters,
          results: AsyncData(PagedMovies.fromPage(page)),
        );
      }
    } catch (error, stackTrace) {
      if (requestId == _requestId) {
        state = SearchState(
          category: category,
          filters: filters,
          results: AsyncError(error, stackTrace),
        );
      }
    }
  }

  Future<void> search(String rawQuery) async {
    final query = rawQuery.trim();
    final category = state.category;
    final filters = state.filters;
    final requestId = ++_requestId;
    if (query.isEmpty) {
      await browse();
      return;
    }

    state = SearchState(
      query: query,
      category: category,
      filters: filters,
      results: const AsyncLoading(),
    );
    try {
      await ref.read(tmdbCredentialProvider.notifier).ready;
      final repository = ref.read(movieRepositoryProvider);
      final page = await _firstMatchingPage(
        (page) => repository.search(
          query: query,
          page: page,
          category: category,
          filters: filters,
        ),
      );
      if (requestId == _requestId) {
        state = SearchState(
          query: query,
          category: category,
          filters: filters,
          results: AsyncData(PagedMovies.fromPage(page)),
        );
      }
    } catch (error, stackTrace) {
      if (requestId == _requestId) {
        state = SearchState(
          query: query,
          category: category,
          filters: filters,
          results: AsyncError(error, stackTrace),
        );
      }
    }
  }

  Future<void> selectCategory(SearchCategory category) async {
    if (category == state.category) return;
    final query = state.query;
    state = SearchState(
      query: query,
      category: category,
      filters: state.filters,
    );
    if (query.isNotEmpty) {
      await search(query);
    } else {
      await browse();
    }
  }

  Future<void> retry() => state.query.isEmpty ? browse() : search(state.query);

  Future<MoviePage> _firstMatchingPage(
    Future<MoviePage> Function(int page) load,
  ) async {
    var page = await load(1);
    while (page.movies.isEmpty &&
        page.page < page.totalPages &&
        page.page < 5) {
      page = await load(page.page + 1);
    }
    return page;
  }

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
      final repository = ref.read(movieRepositoryProvider);
      final page = query.isEmpty
          ? await repository.browse(
              page: current.page + 1,
              category: category,
              filters: state.filters,
            )
          : await repository.search(
              query: query,
              page: current.page + 1,
              category: category,
              filters: state.filters,
            );
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

final movieDetailsProvider = FutureProvider.autoDispose.family<Movie, Movie>((
  ref,
  movie,
) async {
  await ref.read(tmdbCredentialProvider.notifier).ready;
  return ref
      .watch(movieRepositoryProvider)
      .details(movie.id, mediaType: movie.mediaType);
});
