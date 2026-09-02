import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goran_net/src/core/tmdb_client.dart';
import 'package:goran_net/src/models/movie.dart';
import 'package:goran_net/src/models/search_filters.dart';
import 'package:goran_net/src/repositories/movie_repository.dart';
import 'package:goran_net/src/repositories/preferences_repositories.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class MemoryStore implements PreferencesStore {
  final values = <String, String>{};

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }
}

void main() {
  test(
    'TMDB client maps authentication failures to a typed exception',
    () async {
      final client = TmdbClient(
        accessToken: 'bad-token',
        client: MockClient((_) async => http.Response('{}', 401)),
      );

      await expectLater(
        client.get('/trending/movie/day'),
        throwsA(
          isA<AppException>().having(
            (error) => error.type,
            'type',
            AppErrorType.unauthorized,
          ),
        ),
      );
    },
  );

  test('TMDB client rejects a missing token before making a request', () async {
    final client = TmdbClient(accessToken: '');
    await expectLater(
      client.get('/movie/1'),
      throwsA(
        isA<AppException>().having(
          (error) => error.type,
          'type',
          AppErrorType.configuration,
        ),
      ),
    );
  });

  test('bearer prefix is normalized instead of being sent twice', () async {
    late http.Request captured;
    final client = TmdbClient(
      accessToken: '  Bearer eyJvalid.token.value  ',
      client: MockClient((request) async {
        captured = request;
        return http.Response('{"ok":true}', 200);
      }),
    );

    await client.get('/movie/1');

    expect(captured.headers['Authorization'], 'Bearer eyJvalid.token.value');
    expect(captured.url.queryParameters, isNot(contains('api_key')));
  });

  test(
    'a v3 API key passed as access token is detected automatically',
    () async {
      const apiKey = '0123456789abcdef0123456789abcdef';
      late http.Request captured;
      final client = TmdbClient(
        accessToken: apiKey,
        client: MockClient((request) async {
          captured = request;
          return http.Response('{"ok":true}', 200);
        }),
      );

      await client.get('/movie/1');

      expect(captured.url.queryParameters['api_key'], apiKey);
      expect(captured.headers, isNot(contains('Authorization')));
    },
  );

  test('an explicit v3 API key uses the api_key query parameter', () async {
    const apiKey = 'fedcba9876543210fedcba9876543210';
    late http.Request captured;
    final client = TmdbClient(
      accessToken: 'an-old-token-is-ignored',
      apiKey: apiKey,
      client: MockClient((request) async {
        captured = request;
        return http.Response('{"ok":true}', 200);
      }),
    );

    await client.get('/movie/1');

    expect(captured.url.queryParameters['api_key'], apiKey);
    expect(captured.headers, isNot(contains('Authorization')));
  });

  test('search categories use the matching TMDB endpoints', () async {
    final paths = <String>[];
    final client = TmdbClient(
      accessToken: '0123456789abcdef0123456789abcdef',
      client: MockClient((request) async {
        paths.add(request.url.path);
        return http.Response('{"page":1,"total_pages":1,"results":[]}', 200);
      }),
    );
    final repository = TmdbMovieRepository(client);

    await repository.search(query: 'Arcane', page: 1);
    await repository.search(
      query: 'Arcane',
      page: 1,
      category: SearchCategory.series,
    );
    await repository.search(
      query: 'Arcane',
      page: 1,
      category: SearchCategory.anime,
    );

    expect(paths, <String>[
      '/3/search/movie',
      '/3/search/tv',
      '/3/search/multi',
    ]);
  });

  test('browse categories use popular and anime discovery endpoints', () async {
    final requests = <http.Request>[];
    final client = TmdbClient(
      accessToken: '0123456789abcdef0123456789abcdef',
      client: MockClient((request) async {
        requests.add(request);
        return http.Response('{"page":1,"total_pages":1,"results":[]}', 200);
      }),
    );
    final repository = TmdbMovieRepository(client);

    await repository.browse(page: 1);
    await repository.browse(page: 1, category: SearchCategory.series);
    await repository.browse(page: 1, category: SearchCategory.anime);

    expect(requests.map((request) => request.url.path), <String>[
      '/3/movie/popular',
      '/3/tv/popular',
      '/3/discover/tv',
    ]);
    expect(requests.last.url.queryParameters['with_genres'], '16');
  });

  test('browse filters are sent to the TMDB discover endpoint', () async {
    late http.Request captured;
    final client = TmdbClient(
      accessToken: '0123456789abcdef0123456789abcdef',
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          '{"page":1,"total_pages":1,"results":['
          '{"id":8,"title":"Action 2000","release_date":"2000-01-01",'
          '"vote_average":7.8,"genre_ids":[28]}]}',
          200,
        );
      }),
    );

    final page = await TmdbMovieRepository(client).browse(
      page: 1,
      filters: const SearchFilters(
        releaseYear: 2000,
        minimumRating: 7,
        genreIds: <int>{28},
      ),
    );

    expect(captured.url.path, '/3/discover/movie');
    expect(captured.url.queryParameters['primary_release_year'], '2000');
    expect(captured.url.queryParameters['vote_average.gte'], '7.0');
    expect(captured.url.queryParameters['with_genres'], '28');
    expect(page.movies.single.title, 'Action 2000');
  });

  test('genre browsing sends the selected TMDB genre id', () async {
    late http.Request captured;
    final client = TmdbClient(
      accessToken: '0123456789abcdef0123456789abcdef',
      client: MockClient((request) async {
        captured = request;
        return http.Response('{"page":1,"total_pages":1,"results":[]}', 200);
      }),
    );

    await TmdbMovieRepository(
      client,
    ).browseGenre(genre: BrowseGenre.horror, page: 2);

    expect(captured.url.path, '/3/discover/movie');
    expect(captured.url.queryParameters['with_genres'], '27');
    expect(captured.url.queryParameters['page'], '2');
  });

  test('TV details use the TV endpoint and retain their media type', () async {
    late String path;
    final client = TmdbClient(
      accessToken: '0123456789abcdef0123456789abcdef',
      client: MockClient((request) async {
        path = request.url.path;
        return http.Response('{"id":7,"name":"Arcane"}', 200);
      }),
    );

    final result = await TmdbMovieRepository(
      client,
    ).details(7, mediaType: MediaType.tv);

    expect(path, '/3/tv/7');
    expect(result.title, 'Arcane');
    expect(result.mediaType, MediaType.tv);
  });

  test('watchlist round-trips complete local movie summaries', () async {
    final store = MemoryStore();
    final repository = LocalWatchlistRepository(store);
    const movie = Movie(
      id: 9,
      title: 'Offline title',
      overview: 'Stored overview',
      posterPath: '/poster.jpg',
      backdropPath: '/backdrop.jpg',
      releaseDate: '2024-01-02',
      voteAverage: 7.5,
      runtime: 100,
      genres: <String>['Drama'],
    );

    await repository.save(const <Movie>[movie]);
    final loaded = await repository.load();

    expect(loaded, <Movie>[movie]);
    expect(loaded.single.overview, 'Stored overview');
    expect(loaded.single.genres, <String>['Drama']);
  });

  test('corrupt watchlist data falls back to an empty collection', () async {
    final store = MemoryStore()..values['watchlist_v1'] = 'not-json';
    expect(await LocalWatchlistRepository(store).load(), isEmpty);
  });

  test('theme mode persists and unknown values fall back to system', () async {
    final store = MemoryStore();
    final repository = LocalThemeRepository(store);

    expect(await repository.load(), ThemeMode.system);
    await repository.save(ThemeMode.dark);
    expect(await repository.load(), ThemeMode.dark);
    store.values['theme_mode'] = 'unknown';
    expect(await repository.load(), ThemeMode.system);
  });
}
