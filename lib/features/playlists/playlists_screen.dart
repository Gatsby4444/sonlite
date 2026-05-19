import 'dart:io';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/database/app_database.dart';
import '../../core/database/playlists_dao.dart';
import '../../core/database/playlist_repository.dart';
import '../../core/database/track_repository.dart';
import '../../core/services/image_service.dart';
import '../../features/player/providers/player_providers.dart';
import '../../features/player/providers/player_expansion_provider.dart';
import '../player/unified_player_sheet.dart';
import '../shared/track_art.dart';

part 'playlists_screen.g.dart';

enum _ImageSource { gallery, files, remove }

@riverpod
Future<List<PlaylistTrackEntry>> playlistTracks(Ref ref, int playlistId) {
  return ref.watch(playlistRepositoryProvider.notifier).getTracksForPlaylist(playlistId);
}

// ─── Écran liste des playlists ────────────────────────────────────────────────

class PlaylistsScreen extends ConsumerWidget {
  const PlaylistsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistsAsync = ref.watch(playlistRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Playlists')),
      body: playlistsAsync.when(
        data: (playlists) {
          if (playlists.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.queue_music,
                      size: 64,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text('Aucune playlist',
                      style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            );
          }
          return ListView.builder(
            itemCount: playlists.length,
            itemBuilder: (_, i) => PlaylistTile(playlist: playlists[i]),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Erreur: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle playlist'),
        onPressed: () => _showCreateDialog(context, ref),
      ),
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    String? imagePath;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Nouvelle playlist'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () async {
                  final path = await ImageService.pickCropAndSave();
                  if (path != null) setDialogState(() => imagePath = path);
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: imagePath != null
                      ? Image.file(File(imagePath!),
                          width: 80, height: 80, fit: BoxFit.cover)
                      : Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Theme.of(ctx).colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.add_photo_alternate,
                              color: Theme.of(ctx)
                                  .colorScheme
                                  .onSecondaryContainer),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                decoration:
                    const InputDecoration(hintText: 'Nom de la playlist'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler')),
            FilledButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  ref.read(playlistRepositoryProvider.notifier).createPlaylist(
                        name,
                        thumbnailPath: imagePath,
                      );
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Créer'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Tuile playlist ───────────────────────────────────────────────────────────

class PlaylistTile extends ConsumerWidget {
  final Playlist playlist;
  const PlaylistTile({super.key, required this.playlist});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: _PlaylistArt(thumbnailPath: playlist.thumbnailPath),
      title: Text(playlist.name),
      trailing: PopupMenuButton<String>(
        onSelected: (v) => _onMenu(v, context, ref),
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'edit', child: Text('Modifier')),
          PopupMenuItem(value: 'delete', child: Text('Supprimer')),
        ],
      ),
      onTap: () => _openPlaylist(context),
    );
  }

  void _openPlaylist(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlaylistDetailScreen(playlist: playlist),
      ),
    );
  }

  void _onMenu(String value, BuildContext context, WidgetRef ref) {
    switch (value) {
      case 'edit':
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => _EditPlaylistSheet(playlist: playlist),
        );
      case 'delete':
        ref
            .read(playlistRepositoryProvider.notifier)
            .deletePlaylist(playlist.id);
    }
  }
}

// ─── Miniature playlist ───────────────────────────────────────────────────────

class _PlaylistArt extends StatelessWidget {
  final String? thumbnailPath;

  const _PlaylistArt({this.thumbnailPath});

  static const double size = 48;

  @override
  Widget build(BuildContext context) {
    if (thumbnailPath != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.file(
          File(thumbnailPath!),
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (c, e, s) => _defaultArt(context),
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
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(Icons.queue_music,
          color: Theme.of(context).colorScheme.onSecondaryContainer,
          size: size * 0.5),
    );
  }
}

// ─── Sheet modification playlist ─────────────────────────────────────────────

class _EditPlaylistSheet extends ConsumerStatefulWidget {
  final Playlist playlist;
  const _EditPlaylistSheet({required this.playlist});

  @override
  ConsumerState<_EditPlaylistSheet> createState() => _EditPlaylistSheetState();
}

class _EditPlaylistSheetState extends ConsumerState<_EditPlaylistSheet> {
  late final _nameCtrl = TextEditingController(text: widget.playlist.name);
  String? _newImagePath;
  bool _removeImage = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(BuildContext context) async {
    final choice = await showModalBottomSheet<_ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galerie'),
              onTap: () => Navigator.pop(context, _ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: const Text('Fichiers'),
              onTap: () => Navigator.pop(context, _ImageSource.files),
            ),
            if ((_newImagePath ?? widget.playlist.thumbnailPath) != null &&
                !_removeImage)
              ListTile(
                leading: const Icon(Icons.hide_image_outlined),
                title: const Text("Supprimer l'image"),
                onTap: () => Navigator.pop(context, _ImageSource.remove),
              ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    if (choice == _ImageSource.remove) {
      setState(() {
        _removeImage = true;
        _newImagePath = null;
      });
      return;
    }
    final path = choice == _ImageSource.gallery
        ? await ImageService.pickCropAndSave()
        : await ImageService.pickCropAndSaveFromFiles();
    if (path != null) {
      setState(() {
        _newImagePath = path;
        _removeImage = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayImage = _removeImage ? null : (_newImagePath ?? widget.playlist.thumbnailPath);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Modifier la playlist',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          Row(
            children: [
              GestureDetector(
                onTap: () => _pickImage(context),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: displayImage != null
                          ? Image.file(File(displayImage),
                              width: 72, height: 72, fit: BoxFit.cover)
                          : Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .secondaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.add_photo_alternate,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSecondaryContainer),
                            ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(4),
                        child: Icon(Icons.edit,
                            size: 12,
                            color: Theme.of(context).colorScheme.onPrimary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nom',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () async {
              final name = _nameCtrl.text.trim();
              if (name.isEmpty) return;
              final thumb = _removeImage
                  ? null
                  : (_newImagePath ?? widget.playlist.thumbnailPath);
              await ref.read(playlistRepositoryProvider.notifier).updatePlaylist(
                    widget.playlist.id,
                    name,
                    thumbnailPath: thumb,
                  );
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Sauvegarder'),
          ),
        ],
      ),
    );
  }
}

// ─── Écran détail playlist ────────────────────────────────────────────────────

class PlaylistDetailScreen extends ConsumerStatefulWidget {
  final Playlist playlist;
  const PlaylistDetailScreen({super.key, required this.playlist});

  @override
  ConsumerState<PlaylistDetailScreen> createState() =>
      _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState
    extends ConsumerState<PlaylistDetailScreen> {
  List<PlaylistTrackEntry>? _tracks;
  bool _settingsMode = false;

  @override
  void initState() {
    super.initState();
    _loadTracks();
  }

  @override
  void dispose() {
    // Garantit que playerExpandedProvider = false quand on quitte la playlist,
    // même si l'animation de collapse n'a pas eu le temps de se terminer
    // (TickerFuture annulé par dispose — le .then() ne s'exécuterait pas).
    ref.read(playerExpandedProvider.notifier).state = false;
    super.dispose();
  }

  Future<void> _loadTracks() async {
    final tracks = await ref
        .read(playlistRepositoryProvider.notifier)
        .getTracksForPlaylist(widget.playlist.id);
    if (mounted) setState(() => _tracks = tracks);
  }

  @override
  Widget build(BuildContext context) {
    final tracks = _tracks;
    final hasImage = widget.playlist.thumbnailPath != null;

    final actions = [
      if (tracks != null && tracks.isNotEmpty)
        IconButton(
          icon: Icon(
            _settingsMode ? Icons.tune : Icons.tune_outlined,
            color: _settingsMode ? Theme.of(context).colorScheme.primary : null,
          ),
          tooltip: 'Activer/désactiver des morceaux',
          onPressed: () => setState(() => _settingsMode = !_settingsMode),
        ),
      IconButton(
        icon: const Icon(Icons.add),
        tooltip: 'Ajouter des titres',
        onPressed: () => _showAddTracksSheet(context),
      ),
      if (tracks != null && tracks.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.play_arrow),
          onPressed: () => _playAll(tracks),
        ),
    ];

    return Stack(
      children: [
        Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (_, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: hasImage ? 200.0 : null,
            pinned: true,
            forceElevated: innerBoxIsScrolled,
            title: Text(widget.playlist.name),
            actions: actions,
            flexibleSpace: hasImage
                ? FlexibleSpaceBar(
                    collapseMode: CollapseMode.parallax,
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(
                          File(widget.playlist.thumbnailPath!),
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => const SizedBox.shrink(),
                        ),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black54],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : null,
          ),
        ],
        body: tracks == null
            ? const Center(child: CircularProgressIndicator())
            : tracks.isEmpty
                ? const Center(
                    child: Text('Aucun titre dans cette playlist'))
                : ReorderableListView.builder(
                    itemCount: tracks.length,
                    onReorder: _settingsMode ? (_, __) {} : _reorder,
                    buildDefaultDragHandles: !_settingsMode,
                    itemBuilder: (_, i) {
                      final entry = tracks[i];
                      return _PlaylistTrackTile(
                        key: ValueKey(entry.track.id),
                        entry: entry,
                        index: i,
                        settingsMode: _settingsMode,
                        onRemove: () => _confirmRemoveTrack(entry),
                        onPlay: () => _playFrom(tracks, i),
                        onToggleEnabled: (enabled) => _toggleTrack(entry, enabled),
                      );
                    },
                  ),
      ),
        ),
        const UnifiedPlayerSheet(navBarOffset: 0),
      ],
    );
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    if (_tracks == null) return;
    final tracks = List<PlaylistTrackEntry>.from(_tracks!);
    if (newIndex > oldIndex) newIndex--;
    final item = tracks.removeAt(oldIndex);
    tracks.insert(newIndex, item);
    setState(() => _tracks = tracks);
    await ref.read(playlistRepositoryProvider.notifier).reorderTracks(
          widget.playlist.id,
          tracks.map((e) => e.track.id).toList(),
        );
  }

  void _confirmRemoveTrack(PlaylistTrackEntry entry) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Retirer de la playlist'),
        content: Text('Retirer "${entry.track.title}" de cette playlist ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(playlistRepositoryProvider.notifier)
                  .removeTrack(widget.playlist.id, entry.track.id);
              _loadTracks();
            },
            child: const Text('Retirer',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleTrack(PlaylistTrackEntry entry, bool enabled) async {
    await ref
        .read(playlistRepositoryProvider.notifier)
        .setTrackEnabled(widget.playlist.id, entry.track.id, enabled: enabled);
    _loadTracks();
  }

  void _playFrom(List<PlaylistTrackEntry> entries, int index) {
    // Ne jouer que les pistes activées, en commençant à la piste cliquée si elle est activée
    final enabledEntries = entries.where((e) => e.isEnabled).toList();
    if (enabledEntries.isEmpty) return;
    final handler = ref.read(audioHandlerProvider);
    final queue = enabledEntries.map((e) => trackToMediaItem(e.track)).toList();
    // Trouver l'index dans la queue filtrée (ou 0 si la piste est désactivée)
    final clickedTrack = entries[index].track;
    final queueIndex = enabledEntries.indexWhere((e) => e.track.id == clickedTrack.id);
    handler.updateQueue(queue).then((_) {
      handler.skipToQueueItem(queueIndex < 0 ? 0 : queueIndex);
      ref.read(playerExpandedProvider.notifier).state = true;
    });
  }

  void _playAll(List<PlaylistTrackEntry> entries) => _playFrom(entries, 0);

  void _showAddTracksSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddTracksSheet(
        playlistId: widget.playlist.id,
        onAdded: _loadTracks,
      ),
    );
  }
}

// ─── Tuile d'un titre dans la playlist ───────────────────────────────────────

class _PlaylistTrackTile extends ConsumerWidget {
  final PlaylistTrackEntry entry;
  final int index;
  final bool settingsMode;
  final VoidCallback onRemove;
  final VoidCallback onPlay;
  final ValueChanged<bool> onToggleEnabled;

  const _PlaylistTrackTile({
    super.key,
    required this.entry,
    required this.index,
    required this.settingsMode,
    required this.onRemove,
    required this.onPlay,
    required this.onToggleEnabled,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = entry.track;
    final isEnabled = entry.isEnabled;

    Widget tile = ListTile(
      onTap: settingsMode ? null : onPlay,
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!settingsMode)
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(Icons.drag_handle, color: Colors.grey),
              ),
            )
          else
            const SizedBox(width: 32),
          TrackArt(thumbnailPath: track.thumbnailPath),
        ],
      ),
      title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(track.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: settingsMode
          ? CupertinoSwitch(
              value: isEnabled,
              onChanged: onToggleEnabled,
              activeTrackColor: Theme.of(context).colorScheme.primary,
            )
          : PopupMenuButton<String>(
              onSelected: (v) => _onMenu(v, context, ref),
              itemBuilder: (_) => const [
                PopupMenuItem(
                    value: 'remove', child: Text('Retirer de la playlist')),
                PopupMenuItem(value: 'edit', child: Text('Éditer')),
              ],
            ),
    );

    if (!isEnabled) {
      tile = Stack(
        children: [
          tile,
          Positioned.fill(
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 1.2, sigmaY: 1.2),
                child: Opacity(opacity: 0.0, child: Container()),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !settingsMode,
              child: Opacity(opacity: 0.0, child: Container()),
            ),
          ),
        ],
      );
      tile = Opacity(opacity: 0.45, child: tile);
    }

    return tile;
  }

  void _onMenu(String value, BuildContext context, WidgetRef ref) {
    switch (value) {
      case 'remove':
        onRemove();
      case 'edit':
        context.push('/editor/${entry.track.id}');
    }
  }
}

// ─── Bottom sheet pour ajouter des titres ────────────────────────────────────

class AddTracksSheet extends ConsumerStatefulWidget {
  final int playlistId;
  final VoidCallback onAdded;

  const AddTracksSheet({
    super.key,
    required this.playlistId,
    required this.onAdded,
  });

  @override
  ConsumerState<AddTracksSheet> createState() => _AddTracksSheetState();
}

class _AddTracksSheetState extends ConsumerState<AddTracksSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tracksAsync = ref.watch(trackRepositoryProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Ajouter un titre',
                style: Theme.of(context).textTheme.titleMedium),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'Rechercher...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: tracksAsync.when(
              data: (tracks) {
                final filtered = _query.isEmpty
                    ? tracks
                    : tracks
                        .where((t) =>
                            t.title.toLowerCase().contains(_query) ||
                            t.artist.toLowerCase().contains(_query))
                        .toList();
                return ListView.builder(
                  controller: scrollController,
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final track = filtered[i];
                    return ListTile(
                      leading: TrackArt(thumbnailPath: track.thumbnailPath),
                      title: Text(track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      subtitle: Text(track.artist),
                      onTap: () async {
                        await ref
                            .read(playlistRepositoryProvider.notifier)
                            .addTrack(widget.playlistId, track.id);
                        widget.onAdded();
                        if (context.mounted) Navigator.pop(context);
                      },
                    );
                  },
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(child: Text('$e')),
            ),
          ),
        ],
      ),
    );
  }
}
