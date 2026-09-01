import 'package:flutter/material.dart';

class MoviePoster extends StatelessWidget {
  const MoviePoster({required this.url, this.width, this.height, super.key});

  final String? url;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: width,
      height: height,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: const Icon(Icons.movie_outlined, size: 42),
    );
    if (url == null) return placeholder;
    return Image.network(
      url!,
      width: width,
      height: height,
      fit: BoxFit.cover,
      semanticLabel: 'Movie poster',
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) return child;
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            placeholder,
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ],
        );
      },
      errorBuilder: (context, error, stackTrace) => placeholder,
    );
  }
}
