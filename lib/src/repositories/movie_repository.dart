import 'dart:math';

import '../core/tmdb_client.dart';
import '../models/movie.dart';
import '../models/movie_page.dart';
import '../models/search_filters.dart';

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
    SearchFilters filters = const SearchFilters(),
  });
  Future<MoviePage> browseGenre({
    required BrowseGenre genre,
    required int page,
  });
  Future<MoviePage> search({
    required String query,
    required int page,
    SearchCategory category = SearchCategory.movies,
    SearchFilters filters = const SearchFilters(),
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
    SearchFilters filters = const SearchFilters(),
  }) async {
    final useDiscover = category == SearchCategory.anime || !filters.isEmpty;
    final path = useDiscover
        ? category == SearchCategory.movies
              ? '/discover/movie'
              : '/discover/tv'
        : switch (category) {
            SearchCategory.movies => '/movie/popular',
            SearchCategory.series => '/tv/popular',
            SearchCategory.anime => '/discover/tv',
          };
    final json = await _client.get(
      path,
      query: <String, String>{
        'page': '$page',
        'include_adult': filters.ageRating == SearchAgeRating.adultsOnly
            ? 'true'
            : 'false',
        if (useDiscover) ...<String, String>{
          'sort_by': 'popularity.desc',
          if (filters.releaseYear != null)
            category == SearchCategory.movies
                    ? 'primary_release_year'
                    : 'first_air_date_year':
                '${filters.releaseYear}',
          if (filters.minimumRating > 0)
            'vote_average.gte': '${filters.minimumRating}',
          if (filters.minimumRating > 0) 'vote_count.gte': '20',
          if (category == SearchCategory.anime || filters.genreIds.isNotEmpty)
            'with_genres': _discoveryGenres(category, filters.genreIds),
        },
      },
    );
    return _applyFilters(
      MoviePage.fromJson(
        json,
        defaultMediaType: category == SearchCategory.movies
            ? MediaType.movie
            : MediaType.tv,
      ),
      filters,
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
    SearchFilters filters = const SearchFilters(),
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
        if (filters.releaseYear != null)
          category == SearchCategory.movies
                  ? 'primary_release_year'
                  : 'first_air_date_year':
              '${filters.releaseYear}',
      },
    );
    return _applyFilters(
      MoviePage.fromJson(
        json,
        defaultMediaType: category == SearchCategory.series
            ? MediaType.tv
            : MediaType.movie,
        animeOnly: category == SearchCategory.anime,
      ),
      filters,
    );
  }

  String _discoveryGenres(SearchCategory category, Set<int> selected) {
    final mapped = selected.map(
      (id) => switch ((category, id)) {
        (SearchCategory.series || SearchCategory.anime, 28 || 12) => 10759,
        (SearchCategory.series || SearchCategory.anime, 14 || 878) => 10765,
        _ => id,
      },
    );
    final chosen = mapped.toSet().join('|');
    if (category != SearchCategory.anime) return chosen;
    return chosen.isEmpty ? '16' : '16,$chosen';
  }

  MoviePage _applyFilters(MoviePage page, SearchFilters filters) => MoviePage(
    movies: page.movies.where(filters.matches).toList(growable: false),
    page: page.page,
    totalPages: page.totalPages,
  );

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
