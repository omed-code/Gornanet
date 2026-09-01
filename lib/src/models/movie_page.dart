import 'movie.dart';

class MoviePage {
  const MoviePage({
    required this.movies,
    required this.page,
    required this.totalPages,
  });

  final List<Movie> movies;
  final int page;
  final int totalPages;

  factory MoviePage.fromJson(
    Map<String, dynamic> json, {
    MediaType defaultMediaType = MediaType.movie,
    bool animeOnly = false,
  }) {
    final rawResults = json['results'];
    return MoviePage(
      movies: rawResults is List
          ? rawResults
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .where((item) => !animeOnly || _isAnime(item))
                .map(
                  (item) =>
                      Movie.fromJson(item, defaultMediaType: defaultMediaType),
                )
                .where((movie) => movie.id > 0)
                .toList(growable: false)
          : const <Movie>[],
      page: (json['page'] as num?)?.toInt() ?? 1,
      totalPages: (json['total_pages'] as num?)?.toInt() ?? 1,
    );
  }

  static bool _isAnime(Map<String, dynamic> item) {
    final mediaType = item['media_type'];
    if (mediaType != 'movie' && mediaType != 'tv') return false;
    final genreIds = item['genre_ids'];
    return genreIds is List && genreIds.contains(16);
  }
}
