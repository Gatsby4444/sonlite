import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/playlist_repository.dart';

class AddToPlaylistSheet extends ConsumerWidget {
  final int? trackId;
  const AddToPlaylistSheet({super.key, this.trackId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = trackId;
    if (id == null) {
      return const SafeArea(
          child: Center(child: Text('Titre introuvable')));
    }
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
                  child: Text("Aucune playlist — crées-en une d'abord"),
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
                          .addTrack(pl.id, id);
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text('Ajouté à « ${pl.name} »')),
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
