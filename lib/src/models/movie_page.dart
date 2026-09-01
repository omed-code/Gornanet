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

  factory MoviePage.fromJson(Map<String, dynamic> json) {
    final rawResults = json['results'];
    return MoviePage(
      movies: rawResults is List
          ? rawResults
                .whereType<Map>()
                .map((item) => Movie.fromJson(Map<String, dynamic>.from(item)))
                .where((movie) => movie.id > 0)
                .toList(growable: false)
          : const <Movie>[],
      page: (json['page'] as num?)?.toInt() ?? 1,
      totalPages: (json['total_pages'] as num?)?.toInt() ?? 1,
    );
  }
}
