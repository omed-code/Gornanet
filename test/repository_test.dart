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
