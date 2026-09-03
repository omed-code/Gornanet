import 'package:flutter/material.dart';

import '../models/movie.dart';
import 'widgets/movie_card.dart';

class AllTitlesScreen extends StatelessWidget {
  const AllTitlesScreen({required this.title, required this.movies, super.key});

  final String title;
  final List<Movie> movies;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        top: false,
        child: ListView.builder(
          key: const Key('all-titles-list'),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          itemCount: movies.length,
          itemBuilder: (context, index) => Padding(
            padding: EdgeInsets.only(
              bottom: index == movies.length - 1 ? 0 : 14,
            ),
            child: MovieCard(movie: movies[index]),
          ),
        ),
      ),
    );
  }
}
