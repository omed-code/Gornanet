import 'movie.dart';

enum SearchArtworkQuality { any, poster, backdrop }

enum SearchAgeRating { any, allAges, adultsOnly }

class SearchFilters {
  const SearchFilters({
    this.releaseYear,
    this.minimumRating = 0,
    this.genreIds = const <int>{},
    this.quality = SearchArtworkQuality.any,
    this.ageRating = SearchAgeRating.any,
  });

  final int? releaseYear;
  final double minimumRating;
  final Set<int> genreIds;
  final SearchArtworkQuality quality;
  final SearchAgeRating ageRating;

  int get activeCount => <bool>[
    releaseYear != null,
    minimumRating > 0,
    genreIds.isNotEmpty,
    quality != SearchArtworkQuality.any,
    ageRating != SearchAgeRating.any,
  ].where((active) => active).length;

  bool get isEmpty => activeCount == 0;

  bool matches(Movie movie) {
    if (releaseYear != null && movie.releaseYear != '$releaseYear') {
      return false;
    }
    if (movie.voteAverage < minimumRating) return false;
    if (genreIds.isNotEmpty &&
        !genreIds.any(
          (selected) =>
              _equivalentGenreIds(selected).any(movie.genreIds.contains),
        )) {
      return false;
    }
    if (quality == SearchArtworkQuality.poster && movie.posterPath == null) {
      return false;
    }
    if (quality == SearchArtworkQuality.backdrop &&
        movie.backdropPath == null) {
      return false;
    }
    if (ageRating == SearchAgeRating.allAges && movie.adult) return false;
    if (ageRating == SearchAgeRating.adultsOnly && !movie.adult) return false;
    return true;
  }

  static List<int> _equivalentGenreIds(int id) => switch (id) {
    28 || 12 => <int>[28, 12, 10759],
    14 || 878 => <int>[14, 878, 10765],
    _ => <int>[id],
  };
}
