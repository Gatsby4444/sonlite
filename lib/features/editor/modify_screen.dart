import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/track_repository.dart';
import '../../core/services/image_service.dart';
import '../shared/track_art.dart';

class ModifyScreen extends ConsumerStatefulWidget {
  final int trackId;
  const ModifyScreen({super.key, required this.trackId});

  @override
  ConsumerState<ModifyScreen> createState() => _ModifyScreenState();
}

class _ModifyScreenState extends ConsumerState<ModifyScreen> {
  Track? _track;
  late TextEditingController _titleCtrl;
  late TextEditingController _artistCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    _artistCtrl = TextEditingController();
    _loadTrack();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _artistCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTrack() async {
    final track =
        await ref.read(tracksDaoProvider).getTrackById(widget.trackId);
    if (!mounted || track == null) return;
    setState(() {
      _track = track;
      _titleCtrl.text = track.title;
      _artistCtrl.text = track.artist;
    });
  }

  Future<void> _save() async {
    if (_track == null) return;
    setState(() => _saving = true);
    try {
      // toCompanion(false) génère un companion complet (tous les champs),
      // puis copyWith remplace uniquement titre et artiste.
      // replace() exige tous les champs non-null → on doit les fournir tous.
      await ref.read(tracksDaoProvider).updateTrack(
            _track!.toCompanion(false).copyWith(
              title: Value(_titleCtrl.text.trim()),
              artist: Value(_artistCtrl.text.trim()),
            ),
          );
      if (!mounted) return;
      ref.invalidate(trackRepositoryProvider);
      await _loadTrack();
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sauvegardé')),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    }
  }

  void _showImageOptions() {
    if (_track == null) return;
    showModalBottomSheet(
      context: context,
      builder: (_) => _ImageSheet(
        track: _track!,
        onChanged: _loadTrack,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Modifier')),
      body: _track == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                // ── Vignette + bouton modifier image ─────────────────────
                Center(
                  child: GestureDetector(
                    onTap: _showImageOptions,
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: SizedBox(
                            width: 128,
                            height: 128,
                            child:
                                TrackArt(thumbnailPath: _track!.thumbnailPath),
                          ),
                        ),
                        Positioned(
                          bottom: 4,
                          right: 4,
                          child: Material(
                            color: Theme.of(context).colorScheme.primary,
                            shape: const CircleBorder(),
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(Icons.edit,
                                  size: 18, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton.icon(
                    icon: const Icon(Icons.image_outlined, size: 18),
                    label: const Text('Changer l\'image'),
                    onPressed: _showImageOptions,
                  ),
                ),
                const SizedBox(height: 32),
                // ── Renommer ─────────────────────────────────────────────
                TextField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Titre',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _artistCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Artiste',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.save),
                    label: const Text('Sauvegarder'),
                    onPressed: _saving ? null : _save,
                  ),
                ),
              ],
            ),
    );
  }
}

// ─── Bottom sheet image ────────────────────────────────────────────────────────

class _ImageSheet extends ConsumerWidget {
  final Track track;
  final VoidCallback onChanged;

  const _ImageSheet({required this.track, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasOriginal = track.originalThumbnailPath != null;
    final hasCurrent = track.thumbnailPath != null;

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
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Galerie'),
            onTap: () async {
              final notifier = ref.read(trackRepositoryProvider.notifier);
              final trackId = track.id;
              Navigator.pop(context);
              final path = await ImageService.pickCropAndSave();
              if (path != null) {
                await notifier.updateThumbnail(trackId, path);
                onChanged();
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: const Text('Fichiers'),
            onTap: () async {
              final notifier = ref.read(trackRepositoryProvider.notifier);
              final trackId = track.id;
              Navigator.pop(context);
              final path = await ImageService.pickCropAndSaveFromFiles();
              if (path != null) {
                await notifier.updateThumbnail(trackId, path);
                onChanged();
              }
            },
          ),
          if (hasCurrent)
            ListTile(
              leading: const Icon(Icons.hide_image_outlined),
              title: const Text('Supprimer l\'image'),
              subtitle: const Text('Affiche le logo par défaut'),
              onTap: () async {
                final notifier = ref.read(trackRepositoryProvider.notifier);
                Navigator.pop(context);
                await notifier.updateThumbnail(track.id, null);
                onChanged();
              },
            ),
          if (hasOriginal &&
              track.thumbnailPath != track.originalThumbnailPath)
            ListTile(
              leading: const Icon(Icons.restore_outlined),
              title: const Text('Revenir à la miniature d\'origine'),
              subtitle:
                  const Text('Restaure l\'image téléchargée avec le contenu'),
              onTap: () async {
                final notifier = ref.read(trackRepositoryProvider.notifier);
                Navigator.pop(context);
                await notifier.restoreOriginalThumbnail(
                    track.id, track.originalThumbnailPath);
                onChanged();
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
