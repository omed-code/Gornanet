import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goran_net/src/app.dart';
import 'package:goran_net/src/core/tmdb_client.dart';
import 'package:goran_net/src/models/movie.dart';
import 'package:goran_net/src/models/movie_page.dart';
import 'package:goran_net/src/models/search_filters.dart';
import 'package:goran_net/src/repositories/movie_repository.dart';
import 'package:goran_net/src/repositories/preferences_repositories.dart';
import 'package:goran_net/src/state/app_providers.dart';
import 'package:goran_net/src/ui/widgets/credential_dialog.dart';

Movie movie(int id, [String? title]) => Movie(
  id: id,
  title: title ?? 'Movie $id',
  overview: 'A useful overview for movie $id.',
  posterPath: null,
  backdropPath: null,
  releaseDate: '2025-06-01',
  voteAverage: 7.4,
);

class FakeMovieRepository implements MovieRepository {
  FakeMovieRepository({
    this.failTrending = false,
    this.failAuthentication = false,
    this.paginated = false,
  });

  final bool failTrending;
  final bool failAuthentication;
  final bool paginated;
  final trendingPages = <int>[];
  final browseCategories = <SearchCategory>[];
  final browseFilters = <SearchFilters>[];
  final browsedGenres = <BrowseGenre>[];
  final searchQueries = <String>[];
  final searchCategories = <SearchCategory>[];

  @override
  Future<MoviePage> browse({
    required int page,
    SearchCategory category = SearchCategory.movies,
    SearchFilters filters = const SearchFilters(),
  }) async {
    browseCategories.add(category);
    browseFilters.add(filters);
    final label = switch (category) {
      SearchCategory.movies => 'Popular movie',
      SearchCategory.series => 'Popular series',
      SearchCategory.anime => 'Popular anime',
    };
    return MoviePage(
      movies: <Movie>[movie(20 + category.index, label)],
      page: 1,
      totalPages: 1,
    );
  }

  @override
  Future<MoviePage> browseGenre({
    required BrowseGenre genre,
    required int page,
  }) async {
    browsedGenres.add(genre);
    return MoviePage(
      movies: <Movie>[movie(50 + genre.index, '${genre.label} pick')],
      page: 1,
      totalPages: 1,
    );
  }

  @override
  Future<MoviePage> trending({required int page}) async {
    trendingPages.add(page);
    if (failAuthentication) {
      throw const AppException(
        AppErrorType.unauthorized,
        'TMDB rejected the credential.',
      );
    }
    if (failTrending) {
      throw const AppException(
        AppErrorType.network,
        'You appear to be offline.',
      );
    }
    if (paginated && page == 1) {
      return MoviePage(
        movies: List<Movie>.generate(12, (index) => movie(index + 1)),
        page: 1,
        totalPages: 2,
      );
    }
    if (paginated && page == 2) {
      return MoviePage(
        movies: <Movie>[movie(99, 'Page two movie')],
        page: 2,
        totalPages: 2,
      );
    }
    return MoviePage(
      movies: <Movie>[movie(1, 'Arrival')],
      page: 1,
      totalPages: 1,
    );
  }

  @override
  Future<MoviePage> search({
    required String query,
    required int page,
    SearchCategory category = SearchCategory.movies,
    SearchFilters filters = const SearchFilters(),
  }) async {
    searchQueries.add(query);
    searchCategories.add(category);
    return MoviePage(
      movies: <Movie>[movie(7, 'Result for $query')],
      page: 1,
      totalPages: 1,
    );
  }

  @override
  Future<Movie> randomSuggestion() async => movie(88, 'Random surprise');

  @override
  Future<Movie> details(
    int movieId, {
    MediaType mediaType = MediaType.movie,
  }) async => Movie(
    id: movieId,
    title: movieId == 1 ? 'Arrival' : 'Movie $movieId',
    overview: 'Detailed overview',
    posterPath: null,
    backdropPath: null,
    releaseDate: '2025-06-01',
    voteAverage: 8,
    mediaType: mediaType,
    runtime: 118,
    genres: const <String>['Drama'],
  );
}

class FakeWatchlistRepository implements WatchlistRepository {
  FakeWatchlistRepository([List<Movie> initial = const <Movie>[]])
    : movies = List<Movie>.of(initial);

  List<Movie> movies;

  @override
  Future<List<Movie>> load() async => List<Movie>.of(movies);

  @override
  Future<void> save(List<Movie> movies) async {
    this.movies = List<Movie>.of(movies);
  }
}

class FakeThemeRepository implements ThemeRepository {
  ThemeMode mode = ThemeMode.system;

  @override
  Future<ThemeMode> load() async => mode;

  @override
  Future<void> save(ThemeMode mode) async {
    this.mode = mode;
  }
}

class FakeCredentialRepository implements CredentialRepository {
  String? credential;

  @override
  Future<String?> load() async => credential;

  @override
  Future<void> save(String credential) async {
    this.credential = credential;
  }

  @override
  Future<void> clear() async {
    credential = null;
  }
}

class DelayedCredentialRepository implements CredentialRepository {
  final loadCompleter = Completer<String?>();

  @override
  Future<String?> load() => loadCompleter.future;

  @override
  Future<void> save(String credential) async {}

  @override
  Future<void> clear() async {}
}

Future<void> pumpMovieApp(
  WidgetTester tester, {
  MovieRepository? movies,
  FakeWatchlistRepository? watchlist,
  FakeThemeRepository? theme,
  FakeCredentialRepository? credential,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        movieRepositoryProvider.overrideWithValue(
          movies ?? FakeMovieRepository(),
        ),
        watchlistRepositoryProvider.overrideWithValue(
          watchlist ?? FakeWatchlistRepository(),
        ),
        themeRepositoryProvider.overrideWithValue(
          theme ?? FakeThemeRepository(),
        ),
        credentialRepositoryProvider.overrideWithValue(
          credential ?? FakeCredentialRepository(),
        ),
      ],
      child: const MovieApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders trending content inside safe areas', (tester) async {
    await pumpMovieApp(tester);

    expect(find.text('SPIDER MOVIE'), findsOneWidget);
    expect(find.byKey(const Key('app-bar-logo')), findsOneWidget);
    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.centerTitle, isFalse);
    expect(find.text('Arrival'), findsOneWidget);
    expect(find.byType(SafeArea), findsWidgets);
    expect(find.byKey(const Key('home-sections-list')), findsOneWidget);
    final moviesCarousel = tester.widget<PageView>(
      find.byKey(const Key('movies-horizontal-list')),
    );
    expect(moviesCarousel.scrollDirection, Axis.horizontal);
    expect(find.text('Movies'), findsOneWidget);
    expect(find.byKey(const Key('modern-bottom-navigation')), findsOneWidget);
  });

  testWidgets('app bar search button opens the search tab', (tester) async {
    await pumpMovieApp(tester);

    await tester.tap(find.byKey(const Key('app-bar-search')));
    await tester.pumpAndSettle();

    expect(find.text('Find a title'), findsOneWidget);
    expect(find.byKey(const Key('search-category-selector')), findsOneWidget);
    expect(find.text('DISCOVER'), findsOneWidget);
    final field = tester.widget<TextField>(
      find.byKey(const Key('movie-search-field')),
    );
    expect(field.focusNode?.hasFocus, isTrue);
  });

  testWidgets('search hint types a movie title when the tab opens', (
    tester,
  ) async {
    await pumpMovieApp(tester);

    await tester.tap(find.byKey(const Key('app-bar-search')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.textContaining('Try “D'), findsOneWidget);
  });

  testWidgets('search waits for the saved credential during startup', (
    tester,
  ) async {
    final credentials = DelayedCredentialRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          movieRepositoryProvider.overrideWithValue(FakeMovieRepository()),
          watchlistRepositoryProvider.overrideWithValue(
            FakeWatchlistRepository(),
          ),
          themeRepositoryProvider.overrideWithValue(FakeThemeRepository()),
          credentialRepositoryProvider.overrideWithValue(credentials),
        ],
        child: const MovieApp(),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('app-bar-search')));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(find.text('Search failed'), findsNothing);

    credentials.loadCompleter.complete('stored-token');
    await tester.pumpAndSettle();

    expect(find.text('Popular movie'), findsOneWidget);
    expect(find.text('Search failed'), findsNothing);
  });

  testWidgets('shows a retryable network error state', (tester) async {
    await pumpMovieApp(tester, movies: FakeMovieRepository(failTrending: true));

    expect(find.text('Could not load trending movies'), findsOneWidget);
    expect(find.text('You appear to be offline.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('shows setup guidance without a useless auth retry', (
    tester,
  ) async {
    final credentials = FakeCredentialRepository();
    await pumpMovieApp(
      tester,
      movies: FakeMovieRepository(failAuthentication: true),
      credential: credentials,
    );

    expect(find.text('TMDB setup required'), findsOneWidget);
    expect(find.text('TMDB rejected the credential.'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
    await tester.tap(find.text('Add credential'));
    await tester.pumpAndSettle();
    expect(find.text('Connect to TMDB'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('tmdb-credential-field')),
      'YOUR_TOKEN',
    );
    await tester.tap(find.byKey(const Key('save-tmdb-credential')));
    await tester.pump();
    expect(
      find.text('That is a placeholder, not a real TMDB credential.'),
      findsOneWidget,
    );

    const apiKey = '0123456789abcdef0123456789abcdef';
    await tester.enterText(
      find.byKey(const Key('tmdb-credential-field')),
      apiKey,
    );
    await tester.tap(find.byKey(const Key('save-tmdb-credential')));
    await tester.pumpAndSettle();
    expect(credentials.credential, apiKey);
  });

  test('credential validation accepts both supported TMDB formats', () {
    expect(validateTmdbCredential('0123456789abcdef0123456789abcdef'), isNull);
    expect(
      validateTmdbCredential('eyJ${List<String>.filled(90, 'a').join()}'),
      isNull,
    );
    expect(validateTmdbCredential('short-invalid-value'), isNotNull);
  });

  testWidgets('debounces search and renders its result', (tester) async {
    final repository = FakeMovieRepository();
    await pumpMovieApp(tester, movies: repository);

    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('movie-search-field')), 'Dune');
    await tester.pump(const Duration(milliseconds: 300));
    expect(repository.searchQueries, isEmpty);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    expect(repository.searchQueries, <String>['Dune']);
    expect(find.text('Result for Dune'), findsOneWidget);
  });

  testWidgets('search switches between movies, series, and anime', (
    tester,
  ) async {
    final repository = FakeMovieRepository();
    await pumpMovieApp(tester, movies: repository);

    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    expect(find.text('Movies'), findsOneWidget);
    expect(find.text('Anime'), findsOneWidget);
    expect(find.text('Popular movie'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('movie-search-field')), 'One');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Series'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anime'));
    await tester.pumpAndSettle();

    expect(repository.searchCategories, <SearchCategory>[
      SearchCategory.movies,
      SearchCategory.series,
      SearchCategory.anime,
    ]);
  });

  testWidgets('category tabs browse titles without a search query', (
    tester,
  ) async {
    final repository = FakeMovieRepository();
    await pumpMovieApp(tester, movies: repository);

    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    expect(find.text('Popular movie'), findsOneWidget);

    await tester.tap(find.text('Series'));
    await tester.pumpAndSettle();
    expect(find.text('Popular series'), findsOneWidget);

    await tester.tap(find.text('Anime'));
    await tester.pumpAndSettle();
    expect(find.text('Popular anime'), findsOneWidget);
  });

  testWidgets('random suggestion opens a title detail screen', (tester) async {
    await pumpMovieApp(tester);

    await tester.tap(find.byKey(const Key('app-bar-search')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('random-suggestion-logo')), findsOneWidget);
    await tester.tap(find.byKey(const Key('random-suggestion-button')));
    await tester.pumpAndSettle();

    expect(find.text('Movie 88'), findsWidgets);
    expect(find.byKey(const Key('movie-detail-scroll')), findsOneWidget);
  });

  testWidgets('adds a movie and renders the persisted watchlist', (
    tester,
  ) async {
    final watchlist = FakeWatchlistRepository();
    await pumpMovieApp(tester, watchlist: watchlist);

    final arrivalCard = find.ancestor(
      of: find.text('Arrival'),
      matching: find.byType(Card),
    );
    await tester.tap(
      find.descendant(
        of: arrivalCard,
        matching: find.byTooltip('Add to watchlist'),
      ),
    );
    await tester.pumpAndSettle();
    expect(watchlist.movies.single.title, 'Arrival');

    await tester.tap(find.text('Watchlist'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('watchlist-list')), findsOneWidget);
    expect(find.text('Arrival'), findsOneWidget);
  });

  testWidgets('saved titles render when the network is unavailable', (
    tester,
  ) async {
    final watchlist = FakeWatchlistRepository(<Movie>[
      movie(3, 'Saved offline'),
    ]);
    await pumpMovieApp(
      tester,
      movies: FakeMovieRepository(failTrending: true),
      watchlist: watchlist,
    );

    await tester.tap(find.text('Watchlist'));
    await tester.pumpAndSettle();
    expect(find.text('Saved offline'), findsOneWidget);
  });

  testWidgets('switches and persists the dark theme', (tester) async {
    final theme = FakeThemeRepository();
    await pumpMovieApp(tester, theme: theme);

    await tester.tap(find.byTooltip('Choose theme'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark theme'));
    await tester.pumpAndSettle();

    expect(theme.mode, ThemeMode.dark);
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
  });

  testWidgets('detail route initializes, scrolls, and disposes cleanly', (
    tester,
  ) async {
    await pumpMovieApp(tester);

    await tester.tap(find.text('Arrival'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('movie-detail-scroll')), findsOneWidget);
    expect(find.text('118 min'), findsOneWidget);
    await tester.drag(
      find.byKey(const Key('movie-detail-scroll')),
      const Offset(0, -300),
    );
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('home media sections scroll vertically', (tester) async {
    await pumpMovieApp(tester);

    await tester.scrollUntilVisible(
      find.text('Anime'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Anime'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('genre filters load a horizontal carousel', (tester) async {
    final repository = FakeMovieRepository();
    await pumpMovieApp(tester, movies: repository);

    await tester.scrollUntilVisible(
      find.text('Genres'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    final comedyChip = tester.widget<ChoiceChip>(
      find.byKey(const Key('genre-comedy')),
    );
    expect(comedyChip.labelStyle?.color, isNot(Colors.white));
    await tester.tap(find.byKey(const Key('genre-comedy')));
    await tester.pumpAndSettle();

    expect(repository.browsedGenres, contains(BrowseGenre.comedy));
    expect(find.text('Comedy pick'), findsOneWidget);
    final carousel = tester.widget<PageView>(
      find.byKey(const Key('genre-picks-horizontal-list')),
    );
    expect(carousel.scrollDirection, Axis.horizontal);
  });

  testWidgets('movie carousel advances on its staggered six-second timer', (
    tester,
  ) async {
    await pumpMovieApp(tester, movies: FakeMovieRepository(paginated: true));
    final carousel = tester.widget<PageView>(
      find.byKey(const Key('movies-horizontal-list')),
    );
    expect(carousel.controller?.offset, 0);

    await tester.pump(const Duration(seconds: 5));
    expect(carousel.controller?.offset, 0);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 700));

    expect(carousel.controller?.offset, greaterThan(0));
  });

  testWidgets('home sections expose a working see all action', (tester) async {
    await pumpMovieApp(tester);

    await tester.tap(find.text('See all').first);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('all-titles-list')), findsOneWidget);
    expect(find.text('Action titles'), findsOneWidget);
  });

  testWidgets('search filter button opens all filter controls', (tester) async {
    await pumpMovieApp(tester);
    await tester.tap(find.byKey(const Key('app-bar-search')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('search-filter-button')));
    await tester.pumpAndSettle();

    expect(find.text('Released year'), findsOneWidget);
    expect(find.textContaining('Rating ·'), findsOneWidget);
    expect(find.text('Genres'), findsOneWidget);
    expect(find.text('Artwork availability'), findsOneWidget);
    expect(find.text('Content audience'), findsOneWidget);
    expect(find.byKey(const Key('apply-search-filters')), findsOneWidget);
  });

  testWidgets('applying filters reloads browse results with those filters', (
    tester,
  ) async {
    final repository = FakeMovieRepository();
    await pumpMovieApp(tester, movies: repository);
    await tester.tap(find.byKey(const Key('app-bar-search')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('search-filter-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('search-genre-28')));
    await tester.ensureVisible(find.byKey(const Key('apply-search-filters')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('apply-search-filters')));
    await tester.pumpAndSettle();

    expect(repository.browseFilters.last.genreIds, contains(28));
  });
}
