import '../core/tmdb_client.dart';
import '../models/movie.dart';
import '../models/movie_page.dart';

abstract class MovieRepository {
  Future<MoviePage> trending({required int page});
  Future<MoviePage> search({required String query, required int page});
  Future<Movie> details(int movieId);
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
  Future<MoviePage> search({required String query, required int page}) async {
    final json = await _client.get(
      '/search/movie',
      query: <String, String>{
        'query': query,
        'page': '$page',
        'include_adult': 'false',
      },
    );
    return MoviePage.fromJson(json);
  }

  @override
  Future<Movie> details(int movieId) async {
    final json = await _client.get('/movie/$movieId');
    return Movie.fromJson(json);
  }
}
