import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/app_database.dart';
import '../../core/database/playlist_repository.dart';
import '../../core/database/track_repository.dart';
import '../../core/services/import_service.dart';
import '../../features/player/providers/player_providers.dart';
import '../shared/track_art.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracksAsync = ref.watch(trackRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bibliothèque'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => showSearch(
              context: context,
              delegate: _TrackSearchDelegate(ref),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: tracksAsync.when(
        data: (tracks) {
          if (tracks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.music_off,
                      size: 64,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text('Aucune musique',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('Importe des fichiers ou télécharge depuis YouTube',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center),
                ],
              ),
            );
          }
          return TrackList(tracks: tracks);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Erreur: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Importer'),
        onPressed: () => _importFiles(context, ref),
      ),
    );
  }

  Future<void> _importFiles(BuildContext context, WidgetRef ref) async {
    final service = ref.read(importServiceProvider);
    final tracks = await service.pickAndImportFiles();
    if (tracks.isNotEmpty && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${tracks.length} titre(s) importé(s)')),
      );
    }
  }
}

class TrackList extends ConsumerWidget {
  final List<Track> tracks;
  const TrackList({super.key, required this.tracks});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      itemCount: tracks.length,
      itemBuilder: (context, i) =>
          TrackTile(track: tracks[i], allTracks: tracks, index: i),
    );
  }
}

class TrackTile extends ConsumerWidget {
  final Track track;
  final List<Track> allTracks;
  final int index;
  const TrackTile(
      {super.key,
      required this.track,
      required this.allTracks,
      required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: TrackArt(thumbnailPath: track.thumbnailPath),
      title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle:
          Text(track.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: PopupMenuButton<String>(
        onSelected: (v) => _onMenuSelected(v, context, ref),
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'add_to_playlist', child: Text('Ajouter à une playlist')),
          PopupMenuItem(value: 'modify', child: Text('Modifier')),
          PopupMenuItem(value: 'edit', child: Text('Éditer')),
          PopupMenuItem(value: 'delete', child: Text('Supprimer')),
        ],
      ),
      onTap: () => _playFrom(ref, context),
    );
  }

  void _playFrom(WidgetRef ref, BuildContext context) {
    final handler = ref.read(audioHandlerProvider);
    final queue = allTracks.map(trackToMediaItem).toList();
    handler.updateQueue(queue).then((_) => handler.skipToQueueItem(index));
    context.push('/player');
  }

  void _onMenuSelected(String value, BuildContext context, WidgetRef ref) {
    switch (value) {
      case 'add_to_playlist':
        _showAddToPlaylistSheet(context, ref);
      case 'modify':
        context.push('/modify/${track.id}');
      case 'edit':
        context.push('/editor/${track.id}');
      case 'delete':
        _confirmDelete(context, ref);
    }
  }

  void _showAddToPlaylistSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => _AddToPlaylistSheet(track: track),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer'),
        content: Text('Supprimer "${track.title}" ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          TextButton(
            onPressed: () {
              ref
                  .read(trackRepositoryProvider.notifier)
                  .deleteTrack(track.id);
              Navigator.pop(ctx);
            },
            child: const Text('Supprimer',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ─── Sheet "Ajouter à une playlist" ──────────────────────────────────────────

class _AddToPlaylistSheet extends ConsumerWidget {
  final Track track;
  const _AddToPlaylistSheet({required this.track});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistsAsync = ref.watch(playlistRepositoryProvider);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Ajouter à une playlist',
                style: Theme.of(context).textTheme.titleMedium),
          ),
          playlistsAsync.when(
            data: (playlists) {
              if (playlists.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Aucune playlist — crées-en une d\'abord'),
                );
              }
              return ListView.builder(
                shrinkWrap: true,
                itemCount: playlists.length,
                itemBuilder: (_, i) {
                  final pl = playlists[i];
                  return ListTile(
                    leading: const Icon(Icons.queue_music),
                    title: Text(pl.name),
                    onTap: () async {
                      await ref
                          .read(playlistRepositoryProvider.notifier)
                          .addTrack(pl.id, track.id);
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content:
                                  Text('Ajouté à « ${pl.name} »')),
                        );
                      }
                    },
                  );
                },
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Erreur : $e'),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─── Délégué de recherche ─────────────────────────────────────────────────────

class _TrackSearchDelegate extends SearchDelegate<Track?> {
  final WidgetRef ref;
  _TrackSearchDelegate(this.ref);

  @override
  List<Widget> buildActions(BuildContext context) => [
        IconButton(
            icon: const Icon(Icons.clear), onPressed: () => query = ''),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null));

  @override
  Widget buildResults(BuildContext context) => _buildList();

  @override
  Widget buildSuggestions(BuildContext context) => _buildList();

  Widget _buildList() {
    return FutureBuilder<List<Track>>(
      future:
          ref.read(trackRepositoryProvider.notifier).searchTracks(query),
      builder: (context, snapshot) {
        final tracks = snapshot.data ?? [];
        return ListView.builder(
          itemCount: tracks.length,
          itemBuilder: (context, i) => ListTile(
            title: Text(tracks[i].title),
            subtitle: Text(tracks[i].artist),
            onTap: () => close(context, tracks[i]),
          ),
        );
      },
    );
  }
}

