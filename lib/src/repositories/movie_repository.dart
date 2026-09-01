import '../core/tmdb_client.dart';
import '../models/movie.dart';
import '../models/movie_page.dart';

enum SearchCategory { movies, series, anime }

abstract class MovieRepository {
  Future<MoviePage> trending({required int page});
  Future<MoviePage> search({
    required String query,
    required int page,
    SearchCategory category = SearchCategory.movies,
  });
  Future<Movie> details(int movieId, {MediaType mediaType = MediaType.movie});
}

class TmdbMovieRepository implements MovieRepository {
  const TmdbMovieRepository(this._client);

  final TmdbClient _client;

  @override
  Future<MoviePage> trending({required int page}) async {
    final json = await _client.get(
      '/trending/movie/day',
      query: <String, String>{'page': '$page'},
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
  Future<Movie> details(
    int movieId, {
    MediaType mediaType = MediaType.movie,
  }) async {
    final json = await _client.get('/${mediaType.name}/$movieId');
    return Movie.fromJson(json, defaultMediaType: mediaType);
  }
}
