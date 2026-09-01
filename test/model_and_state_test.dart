import 'package:flutter_test/flutter_test.dart';
import 'package:goran_net/src/models/movie.dart';
import 'package:goran_net/src/models/movie_page.dart';
import 'package:goran_net/src/state/app_providers.dart';

void main() {
  group('Movie parsing', () {
    test('parses details and nullable fields safely', () {
      final movie = Movie.fromJson(<String, dynamic>{
        'id': 42,
        'title': 'Arrival',
        'overview': null,
        'poster_path': null,
        'release_date': '',
        'vote_average': 8,
        'runtime': 116,
        'genres': <Map<String, dynamic>>[
          <String, dynamic>{'id': 18, 'name': 'Drama'},
        ],
      });

      expect(movie.id, 42);
      expect(movie.overview, isEmpty);
      expect(movie.releaseYear, 'TBA');
      expect(movie.voteAverage, 8.0);
      expect(movie.genres, <String>['Drama']);
    });

    test('uses safe defaults for malformed movie data', () {
      final movie = Movie.fromJson(<String, dynamic>{});
      expect(movie.id, 0);
      expect(movie.title, 'Untitled');
      expect(movie.posterUrl, isNull);
    });

    test('movie page filters invalid rows', () {
      final page = MoviePage.fromJson(<String, dynamic>{
        'page': 1,
        'total_pages': 2,
        'results': <Object?>[
          <String, dynamic>{'id': 1, 'title': 'Valid'},
          <String, dynamic>{'title': 'Missing id'},
          'invalid',
        ],
      });
      expect(page.movies.map((movie) => movie.id), <int>[1]);
    });

    test('parses TV titles and anime media types', () {
      final page = MoviePage.fromJson(<String, dynamic>{
        'results': <Object?>[
          <String, dynamic>{
            'id': 7,
            'name': 'Frieren',
            'first_air_date': '2023-09-29',
            'media_type': 'tv',
            'genre_ids': <int>[16, 10765],
          },
          <String, dynamic>{
            'id': 8,
            'title': 'Not animated',
            'media_type': 'movie',
            'genre_ids': <int>[18],
          },
        ],
      }, animeOnly: true);

      expect(page.movies.single.title, 'Frieren');
      expect(page.movies.single.mediaType, MediaType.tv);
      expect(page.movies.single.releaseYear, '2023');
    });
  });

  test('pagination merges pages and removes duplicate movie ids', () {
    const first = Movie(
      id: 1,
      title: 'First',
      overview: '',
      posterPath: null,
      backdropPath: null,
      releaseDate: null,
      voteAverage: 0,
    );
    const updated = Movie(
      id: 1,
      title: 'Updated',
      overview: '',
      posterPath: null,
      backdropPath: null,
      releaseDate: null,
      voteAverage: 0,
    );
    const second = Movie(
      id: 2,
      title: 'Second',
      overview: '',
      posterPath: null,
      backdropPath: null,
      releaseDate: null,
      voteAverage: 0,
    );
    final merged =
        const PagedMovies(
          movies: <Movie>[first],
          page: 1,
          totalPages: 2,
        ).append(
          const MoviePage(
            movies: <Movie>[updated, second],
            page: 2,
            totalPages: 2,
          ),
        );

    expect(merged.movies, hasLength(2));
    expect(merged.movies.first.title, 'Updated');
    expect(merged.canLoadMore, isFalse);
  });
}
