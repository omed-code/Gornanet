import 'dart:math';

import '../core/tmdb_client.dart';
import '../models/movie.dart';
import '../models/movie_page.dart';

enum SearchCategory { movies, series, anime }

enum BrowseGenre {
  action(28, 'Action'),
  comedy(35, 'Comedy'),
  drama(18, 'Drama'),
  horror(27, 'Horror'),
  scienceFiction(878, 'Sci-Fi'),
  romance(10749, 'Romance');

  const BrowseGenre(this.id, this.label);

  final int id;
  final String label;
}

abstract class MovieRepository {
  Future<MoviePage> trending({required int page});
  Future<MoviePage> browse({
    required int page,
    SearchCategory category = SearchCategory.movies,
  });
  Future<MoviePage> browseGenre({
    required BrowseGenre genre,
    required int page,
  });
  Future<MoviePage> search({
    required String query,
    required int page,
    SearchCategory category = SearchCategory.movies,
  });
  Future<Movie> randomSuggestion();
  Future<Movie> details(int movieId, {MediaType mediaType = MediaType.movie});
}

class TmdbMovieRepository implements MovieRepository {
  TmdbMovieRepository(this._client, {Random? random})
    : _random = random ?? Random();

  final TmdbClient _client;
  final Random _random;

  @override
  Future<MoviePage> trending({required int page}) async {
    final json = await _client.get(
      '/trending/movie/day',
      query: <String, String>{'page': '$page'},
    );
    return MoviePage.fromJson(json);
  }

  @override
  Future<MoviePage> browse({
    required int page,
    SearchCategory category = SearchCategory.movies,
  }) async {
    final path = switch (category) {
      SearchCategory.movies => '/movie/popular',
      SearchCategory.series => '/tv/popular',
      SearchCategory.anime => '/discover/tv',
    };
    final json = await _client.get(
      path,
      query: <String, String>{
        'page': '$page',
        'include_adult': 'false',
        if (category == SearchCategory.anime) ...<String, String>{
          'with_genres': '16',
          'sort_by': 'popularity.desc',
        },
      },
    );
    return MoviePage.fromJson(
      json,
      defaultMediaType: category == SearchCategory.movies
          ? MediaType.movie
          : MediaType.tv,
    );
  }

  @override
  Future<MoviePage> browseGenre({
    required BrowseGenre genre,
    required int page,
  }) async {
    final json = await _client.get(
      '/discover/movie',
      query: <String, String>{
        'page': '$page',
        'with_genres': '${genre.id}',
        'sort_by': 'popularity.desc',
        'include_adult': 'false',
      },
    );
    return MoviePage.fromJson(json);
  }

  @override
  Future<MoviePage> search({
    required String query,
    required int page,
    SearchCategory category = SearchCategory.movies,
  }) async {
    final path = switch (category) {
      SearchCategory.movies => '/search/movie',
      SearchCategory.series => '/search/tv',
      SearchCategory.anime => '/search/multi',
    };
    final json = await _client.get(
      path,
      query: <String, String>{
        'query': query,
        'page': '$page',
        'include_adult': 'false',
      },
    );
    return MoviePage.fromJson(
      json,
      defaultMediaType: category == SearchCategory.series
          ? MediaType.tv
          : MediaType.movie,
      animeOnly: category == SearchCategory.anime,
    );
  }

  @override
  Future<Movie> randomSuggestion() async {
    final categories = SearchCategory.values;
    final category = categories[_random.nextInt(categories.length)];
    final page = await browse(
      page: _random.nextInt(10) + 1,
      category: category,
    );
    if (page.movies.isEmpty) {
      throw const AppException(
        AppErrorType.server,
        'Could not find a random title. Please try again.',
      );
    }
    return page.movies[_random.nextInt(page.movies.length)];
  }

  @override
  Future<Movie> details(
    int movieId, {
    MediaType mediaType = MediaType.movie,
  }) async {
    final json = await _client.get('/${mediaType.name}/$movieId');
    return Movie.fromJson(json, defaultMediaType: mediaType);
  }
}
