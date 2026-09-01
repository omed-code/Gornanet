import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goran_net/src/core/tmdb_client.dart';
import 'package:goran_net/src/models/movie.dart';
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
