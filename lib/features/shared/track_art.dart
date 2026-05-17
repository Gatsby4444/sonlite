import 'dart:io';
import 'package:flutter/material.dart';

class TrackArt extends StatelessWidget {
  final String? thumbnailPath;
  final double size;
  final double borderRadius;

  const TrackArt({
    super.key,
    this.thumbnailPath,
    this.size = 48,
    this.borderRadius = 4,
  });

  @override
  Widget build(BuildContext context) {
    if (thumbnailPath != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.file(
          File(thumbnailPath!),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, e, s) => _defaultArt(context),
        ),
      );
    }
    return _defaultArt(context);
  }

  Widget _defaultArt(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Icon(
        Icons.music_note,
        size: size * 0.5,
        color: Theme.of(context).colorScheme.onPrimaryContainer,
      ),
    );
  }
}
