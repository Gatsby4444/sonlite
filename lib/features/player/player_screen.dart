import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/app_database.dart';
import '../../core/database/playlist_repository.dart';
import '../../core/database/track_repository.dart';
import 'package:audio_service/audio_service.dart';

import '../../core/services/audio_handler.dart';
import '../../core/services/image_service.dart';
import 'providers/player_providers.dart';

// ─── Écran principal ──────────────────────────────────────────────────────────

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  // PageController centré sur la page 1 : 0=prev, 1=current, 2=next
  late final PageController _pageCtrl;
  bool _navigating = false;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController(initialPage: 1);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  // Appelé par PageView quand la page change (swipe complété).
  // On navigue dans l'audio handler puis on revient immédiatement à la
  // page 1 (sans animation) pour que le carousel soit toujours centré.
  void _onPageChanged(int page, SonLiteAudioHandler handler) {
    if (page == 1) return;
    if (_navigating) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pageCtrl.hasClients) _pageCtrl.jumpToPage(1);
      });
      return;
    }
    _navigating = true;
    if (page == 0) {
      handler.skipToPrevious();
    } else {
      handler.skipToNext();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _pageCtrl.hasClients) _pageCtrl.jumpToPage(1);
      _navigating = false;
    });
  }

  Future<void> _handleMenu(
      String action, BuildContext ctx, MediaItem item) async {
    final trackId = item.extras?['trackId'] as int?;
    final handler = ref.read(audioHandlerProvider);

    switch (action) {
      case 'edit':
        if (trackId != null && ctx.mounted) ctx.push('/editor/$trackId');

      case 'add_to_playlist':
        if (!ctx.mounted) return;
        showModalBottomSheet(
          context: ctx,
          builder: (_) => _AddToPlaylistSheet(trackId: trackId),
        );

      case 'change_image':
        if (trackId == null) return;
        final track = await ref.read(tracksDaoProvider).getTrackById(trackId);
        if (track == null || !ctx.mounted) return;
        showModalBottomSheet(
          context: ctx,
          builder: (_) => _ImageOptionsSheet(track: track),
        );

      case 'loop_config':
        if (!ctx.mounted) return;
        showDialog(
          context: ctx,
          builder: (_) => _LoopDialog(handler: handler),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaItem = ref.watch(currentMediaItemProvider).valueOrNull;
    final playbackState = ref.watch(playbackStateProvider).valueOrNull;
    final handler = ref.read(audioHandlerProvider);

    if (mediaItem == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Aucune musique en cours')),
      );
    }

    final isPlaying = playbackState?.playing ?? false;
    final position =
        ref.watch(audioPositionProvider).valueOrNull ?? Duration.zero;
    final duration = mediaItem.duration ?? Duration.zero;
    final loopState =
        ref.watch(loopStateProvider).valueOrNull ?? handler.loopState;
    final shuffle = ref.watch(shuffleEnabledProvider).valueOrNull ?? false;

    final queue = ref.watch(audioQueueProvider).valueOrNull ?? const [];
    final idx = queue.indexWhere((e) => e.id == mediaItem.id);
    final prevItem = idx > 0 ? queue[idx - 1] : null;
    final nextItem =
        idx >= 0 && idx < queue.length - 1 ? queue[idx + 1] : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lecture'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) => _handleMenu(v, context, mediaItem),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Éditer')),
              PopupMenuItem(
                  value: 'change_image', child: Text("Changer l'image")),
              PopupMenuItem(
                  value: 'add_to_playlist',
                  child: Text('Ajouter à une playlist')),
              PopupMenuItem(
                  value: 'loop_config',
                  child: Text('Configurer la boucle')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Zone swipeable : artwork uniquement ────────────────────────────
          // PageView gère nativement le geste à 60 fps.
          // Le Slider est hors de ce widget → aucun conflit de gesture.
          Expanded(
            child: PageView(
              controller: _pageCtrl,
              onPageChanged: (page) => _onPageChanged(page, handler),
              children: [
                _ArtworkPage(item: prevItem),
                _ArtworkPage(item: mediaItem),
                _ArtworkPage(item: nextItem),
              ],
            ),
          ),

          // ── Contrôles fixes ───────────────────────────────────────────────
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 32).copyWith(bottom: 32),
            child: Column(
              children: [
                const SizedBox(height: 24),

                // Titre + artiste — fondu au changement de piste
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Column(
                    key: ValueKey(mediaItem.id),
                    children: [
                      Text(
                        mediaItem.title,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        mediaItem.artist ?? '',
                        style:
                            Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Slider de position
                _PositionSlider(
                  position: position,
                  duration: duration,
                  onSeek: handler.seek,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_fmt(position),
                        style: Theme.of(context).textTheme.bodySmall),
                    Text(_fmt(duration),
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
                const SizedBox(height: 32),

                // Contrôles principaux
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      iconSize: 40,
                      icon: const Icon(Icons.skip_previous),
                      onPressed: handler.skipToPrevious,
                    ),
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      child: IconButton(
                        iconSize: 48,
                        color: Theme.of(context).colorScheme.onPrimary,
                        icon:
                            Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                        onPressed: isPlaying ? handler.pause : handler.play,
                      ),
                    ),
                    IconButton(
                      iconSize: 40,
                      icon: const Icon(Icons.skip_next),
                      onPressed: handler.skipToNext,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _RepeatButton(
                        loopState: loopState,
                        onTap: handler.cycleTrackLoop),
                    const SizedBox(width: 24),
                    IconButton(
                      icon: Icon(
                        Icons.shuffle,
                        color: shuffle
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      onPressed: () => handler.setShuffle(!shuffle),
                      tooltip:
                          shuffle ? 'Aléatoire activé' : 'Lecture aléatoire',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}

// ─── Page artwork du PageView ─────────────────────────────────────────────────

class _ArtworkPage extends StatelessWidget {
  final MediaItem? item;
  const _ArtworkPage({this.item});

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

// ─── Bouton repeat style Spotify ─────────────────────────────────────────────

class _RepeatButton extends StatelessWidget {
  final int loopState;
  final VoidCallback onTap;
  const _RepeatButton({required this.loopState, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = loopState != 0;
    final color = active
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final label = loopState == 1
        ? '1'
        : loopState == 2
            ? '2'
            : loopState == -1
                ? '∞'
                : null;

    return Tooltip(
      message: loopState == 0
          ? 'Boucle désactivée'
          : loopState == -1
              ? 'Boucle infinie'
              : 'Boucle ×$loopState',
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(Icons.repeat, color: color, size: 28),
              if (label != null)
                Text(
                  label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: color,
                      height: 1),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Slider de position ───────────────────────────────────────────────────────

class _PositionSlider extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;
  const _PositionSlider(
      {required this.position,
      required this.duration,
      required this.onSeek});

  @override
  State<_PositionSlider> createState() => _PositionSliderState();
}

class _PositionSliderState extends State<_PositionSlider> {
  double? _drag;

  String _fmt(double ms) {
    final d = Duration(milliseconds: ms.round());
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final max = widget.duration.inMilliseconds.toDouble();
    final val = (_drag ?? widget.position.inMilliseconds.toDouble())
        .clamp(0.0, max > 0 ? max : 1.0);

    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 6,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
        activeTrackColor: Theme.of(context).colorScheme.primary,
        inactiveTrackColor:
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.25),
        showValueIndicator: ShowValueIndicator.onDrag,
        valueIndicatorColor: Theme.of(context).colorScheme.primary,
        valueIndicatorTextStyle: TextStyle(
            color: Theme.of(context).colorScheme.onPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600),
      ),
      child: Slider(
        min: 0,
        max: max > 0 ? max : 1,
        value: val,
        label: _fmt(val),
        onChanged: (v) => setState(() => _drag = v),
        onChangeEnd: (v) {
          widget.onSeek(Duration(milliseconds: v.round()));
          setState(() => _drag = null);
        },
      ),
    );
  }
}

// ─── Sheet "Ajouter à une playlist" ──────────────────────────────────────────

class _AddToPlaylistSheet extends ConsumerWidget {
  final int? trackId;
  const _AddToPlaylistSheet({this.trackId});

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

// ─── Sheet "Options image" ────────────────────────────────────────────────────

class _ImageOptionsSheet extends ConsumerWidget {
  final Track track;
  const _ImageOptionsSheet({required this.track});

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
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choisir depuis la galerie'),
            onTap: () async {
              final notifier = ref.read(trackRepositoryProvider.notifier);
              final trackId = track.id;
              Navigator.pop(context);
              final path = await ImageService.pickCropAndSave();
              if (path != null) {
                await notifier.updateThumbnail(trackId, path);
              }
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

// ─── Dialog de configuration de boucle ───────────────────────────────────────

class _LoopDialog extends StatefulWidget {
  final SonLiteAudioHandler handler;
  const _LoopDialog({required this.handler});

  @override
  State<_LoopDialog> createState() => _LoopDialogState();
}

class _LoopDialogState extends State<_LoopDialog> {
  int _mode = 0;
  bool _stopAfter = false;
  final _countCtrl = TextEditingController(text: '1');

  @override
  void dispose() {
    _countCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Configurer la boucle'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RadioRow(
              label: const Text('Désactivée'),
              selected: _mode == 0,
              onTap: () => setState(() => _mode = 0)),
          _RadioRow(
            label: Row(children: [
              const Text('Répéter '),
              SizedBox(
                width: 48,
                child: TextField(
                  controller: _countCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(isDense: true),
                  onTap: () => setState(() => _mode = 1),
                ),
              ),
              const Text(' fois'),
            ]),
            selected: _mode == 1,
            onTap: () => setState(() => _mode = 1),
          ),
          _RadioRow(
              label: const Text('Infinie'),
              selected: _mode == 2,
              onTap: () => setState(() => _mode = 2)),
          if (_mode == 1)
            CheckboxListTile(
              title: const Text('Arrêter après la boucle'),
              value: _stopAfter,
              onChanged: (v) => setState(() => _stopAfter = v ?? false),
            ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler')),
        FilledButton(
          onPressed: () {
            if (_mode == 0) {
              widget.handler.setLoopConfig(AudioLoopMode.off);
            } else if (_mode == 1) {
              widget.handler.setLoopConfig(
                AudioLoopMode.oneWithCount,
                count: int.tryParse(_countCtrl.text) ?? 1,
                stopAfter: _stopAfter,
              );
            } else {
              widget.handler
                  .setLoopConfig(AudioLoopMode.oneWithCount, count: 0);
            }
            Navigator.of(context).pop();
          },
          child: const Text('Appliquer'),
        ),
      ],
    );
  }
}

class _RadioRow extends StatelessWidget {
  final Widget label;
  final bool selected;
  final VoidCallback onTap;
  const _RadioRow(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Expanded(child: label),
        ],
      ),
    );
  }
}
