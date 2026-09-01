enum MediaType { movie, tv }

class Movie {
  const Movie({
    required this.id,
    required this.title,
    required this.overview,
    required this.posterPath,
    required this.backdropPath,
    required this.releaseDate,
    required this.voteAverage,
    this.mediaType = MediaType.movie,
    this.runtime,
    this.genres = const <String>[],
  });

  final int id;
  final String title;
  final String overview;
  final String? posterPath;
  final String? backdropPath;
  final String? releaseDate;
  final double voteAverage;
  final MediaType mediaType;
  final int? runtime;
  final List<String> genres;

  String get releaseYear {
    final date = releaseDate;
    return date != null && date.length >= 4 ? date.substring(0, 4) : 'TBA';
  }

  String? get posterUrl =>
      posterPath == null ? null : 'https://image.tmdb.org/t/p/w500$posterPath';

  String? get backdropUrl => backdropPath == null
      ? null
      : 'https://image.tmdb.org/t/p/w780$backdropPath';

  String get identityKey => '${mediaType.name}:$id';

  factory Movie.fromJson(
    Map<String, dynamic> json, {
    MediaType defaultMediaType = MediaType.movie,
  }) {
    final rawGenres = json['genres'];
    final rawRuntime = json['episode_run_time'];
    final mediaType = switch (_string(json['media_type'])) {
      'tv' => MediaType.tv,
      'movie' => MediaType.movie,
      _ => defaultMediaType,
    };
    return Movie(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title:
          _string(json['title']) ??
          _string(json['original_title']) ??
          _string(json['name']) ??
          _string(json['original_name']) ??
          'Untitled',
      overview: _string(json['overview']) ?? '',
      posterPath: _string(json['poster_path']),
      backdropPath: _string(json['backdrop_path']),
      releaseDate:
          _string(json['release_date']) ?? _string(json['first_air_date']),
      voteAverage: (json['vote_average'] as num?)?.toDouble() ?? 0,
      mediaType: mediaType,
      runtime:
          (json['runtime'] as num?)?.toInt() ??
          (rawRuntime is List && rawRuntime.isNotEmpty
              ? (rawRuntime.first as num?)?.toInt()
              : null),
      genres: rawGenres is List
          ? rawGenres
                .whereType<Map>()
                .map((genre) => _string(genre['name']))
                .whereType<String>()
                .toList(growable: false)
          : const <String>[],
    );
  }

  factory Movie.fromStoredJson(Map<String, dynamic> json) =>
      Movie.fromJson(json);

  Map<String, dynamic> toStoredJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'overview': overview,
    'poster_path': posterPath,
    'backdrop_path': backdropPath,
    'release_date': releaseDate,
    'vote_average': voteAverage,
    'media_type': mediaType.name,
    'runtime': runtime,
    'genres': genres.map((name) => <String, String>{'name': name}).toList(),
  };

  Movie mergeDetails(Movie details) => Movie(
    id: id,
    title: details.title,
    overview: details.overview.isEmpty ? overview : details.overview,
    posterPath: details.posterPath ?? posterPath,
    backdropPath: details.backdropPath ?? backdropPath,
    releaseDate: details.releaseDate ?? releaseDate,
    voteAverage: details.voteAverage,
    mediaType: mediaType,
    runtime: details.runtime,
    genres: details.genres,
  );

  static String? _string(Object? value) {
    if (value is! String || value.trim().isEmpty) return null;
    return value;
  }

  @override
  bool operator ==(Object other) =>
      other is Movie && other.id == id && other.mediaType == mediaType;

  @override
  int get hashCode => Object.hash(id, mediaType);
}
