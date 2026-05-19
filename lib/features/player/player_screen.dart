import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/track_repository.dart';
import '../../core/services/audio_handler.dart';
import 'providers/player_providers.dart';
import 'widgets/add_to_playlist_sheet.dart';
import 'widgets/artwork_page.dart';
import 'widgets/image_options_sheet.dart';
import 'widgets/loop_dialog.dart';
import 'widgets/position_slider.dart';
import 'widgets/repeat_button.dart';

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
          builder: (_) => AddToPlaylistSheet(trackId: trackId),
        );

      case 'change_image':
        if (trackId == null) return;
        final track = await ref.read(tracksDaoProvider).getTrackById(trackId);
        if (track == null || !ctx.mounted) return;
        showModalBottomSheet(
          context: ctx,
          builder: (_) => ImageOptionsSheet(track: track),
        );

      case 'loop_config':
        if (!ctx.mounted) return;
        showDialog(
          context: ctx,
          builder: (_) => LoopDialog(handler: handler),
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
          // PageView gère nativement le geste à 60 fps.
          // Le Slider est hors de ce widget → aucun conflit de gesture.
          Expanded(
            child: PageView(
              controller: _pageCtrl,
              onPageChanged: (page) => _onPageChanged(page, handler),
              children: [
                PlayerArtworkPage(item: prevItem),
                PlayerArtworkPage(item: mediaItem),
                PlayerArtworkPage(item: nextItem),
              ],
            ),
          ),

          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 32).copyWith(bottom: 32),
            child: Column(
              children: [
                const SizedBox(height: 24),

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

                PlayerPositionSlider(
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
                    PlayerRepeatButton(
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
