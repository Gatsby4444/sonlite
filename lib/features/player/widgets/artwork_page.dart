import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

class PlayerArtworkPage extends StatelessWidget {
  final MediaItem? item;
  const PlayerArtworkPage({super.key, this.item});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: _buildArt(context),
      ),
    );
  }

  Widget _buildArt(BuildContext context) {
    final uri = item?.artUri;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: uri != null
          ? Image.file(
              File(uri.toFilePath()),
              width: 280,
              height: 280,
              fit: BoxFit.cover,
              errorBuilder: (c, e, s) => _defaultArt(context),
            )
          : _defaultArt(context),
    );
  }

  Widget _defaultArt(BuildContext context) => Container(
        width: 280,
        height: 280,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(Icons.music_note,
            size: 80,
            color: Theme.of(context).colorScheme.onPrimaryContainer),
      );
}
