import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/track_repository.dart';
import '../../../core/services/image_service.dart';

class ImageOptionsSheet extends ConsumerWidget {
  final Track track;
  const ImageOptionsSheet({super.key, required this.track});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasCurrent = track.thumbnailPath != null;
    final hasOriginal = track.originalThumbnailPath != null;
    final isCustomized = track.thumbnailPath != track.originalThumbnailPath;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Image du titre',
                style: Theme.of(context).textTheme.titleMedium),
          ),
          ListTile(
            leading: const Icon(Icons.image_outlined),
            title: const Text('Choisir une image'),
            subtitle: const Text('Galerie, photos, fichiers…'),
            onTap: () async {
              final notifier = ref.read(trackRepositoryProvider.notifier);
              final trackId = track.id;
              Navigator.pop(context);
              final path = await ImageService.pickCropAndSaveFromFiles();
              if (path != null) await notifier.updateThumbnail(trackId, path);
            },
          ),
          if (hasCurrent)
            ListTile(
              leading: const Icon(Icons.hide_image_outlined),
              title: const Text("Supprimer l'image"),
              subtitle: const Text('Affiche le logo par défaut'),
              onTap: () async {
                await ref
                    .read(trackRepositoryProvider.notifier)
                    .updateThumbnail(track.id, null);
                if (context.mounted) Navigator.pop(context);
              },
            ),
          if (hasOriginal && isCustomized)
            ListTile(
              leading: const Icon(Icons.restore_outlined),
              title: const Text("Revenir à la miniature d'origine"),
              subtitle:
                  const Text('Restaure l\'image téléchargée avec le contenu'),
              onTap: () async {
                await ref
                    .read(trackRepositoryProvider.notifier)
                    .restoreOriginalThumbnail(
                        track.id, track.originalThumbnailPath);
                if (context.mounted) Navigator.pop(context);
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
