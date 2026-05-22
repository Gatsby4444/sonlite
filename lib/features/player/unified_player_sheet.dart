import 'dart:io';
import 'dart:ui' as ui;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/track_repository.dart';
import '../../core/services/audio_handler.dart';
import 'providers/player_expansion_provider.dart';
import 'providers/player_providers.dart';
import 'widgets/add_to_playlist_sheet.dart';
import 'widgets/image_options_sheet.dart';
import 'widgets/loop_dialog.dart';
import 'widgets/position_slider.dart';
import 'widgets/repeat_button.dart';

const double _kMiniHeight = 72.0;
const double _kNavBarHeight = 80.0;

// ─── Lecteur unifié ───────────────────────────────────────────────────────────

class UnifiedPlayerSheet extends ConsumerStatefulWidget {
  /// Offset au-dessus du bas pour le mini-player.
  /// Dans AppShell (avec NavigationBar) : _kNavBarHeight (défaut).
  /// Dans les écrans sans NavigationBar : 0.
  final double navBarOffset;
  const UnifiedPlayerSheet({super.key, this.navBarOffset = _kNavBarHeight});

  @override
  ConsumerState<UnifiedPlayerSheet> createState() => _UnifiedPlayerSheetState();
}

class _UnifiedPlayerSheetState extends ConsumerState<UnifiedPlayerSheet>
    with TickerProviderStateMixin {
  late final AnimationController _expandCtrl;
  late final AnimationController _swipeCtrl;

  // 1 = piste suivante entre depuis la droite, -1 = précédente depuis la gauche
  int _swipeDirection = 1;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _expandCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _swipeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      lowerBound: -1.0,
      upperBound: 1.0,
      value: 0.0,
    );
  }

  @override
  void dispose() {
    _expandCtrl.dispose();
    _swipeCtrl.dispose();
    super.dispose();
  }

  // ── Expansion verticale ──────────────────────────────────────────────────────

  void _expand() {
    _expandCtrl.animateTo(1.0, curve: Curves.easeOutCubic);
    ref.read(playerExpandedProvider.notifier).state = true;
  }

  void _collapse() {
    _expandCtrl.animateTo(0.0, curve: Curves.easeInCubic).then((_) {
      ref.read(playerExpandedProvider.notifier).state = false;
    });
  }

  void _onVerticalDragUpdate(DragUpdateDetails d) {
    // Ignorer les gestes principalement horizontaux : évite la fermeture accidentelle
    // lors d'un swipe artwork (le doigt dévie légèrement vers le bas)
    if (d.delta.dx.abs() > d.delta.dy.abs()) return;
    final delta = -d.delta.dy;
    final screenH = MediaQuery.sizeOf(context).height;
    final sensitivity = ui.lerpDouble(4.0, 1.0, _expandCtrl.value)!;
    _expandCtrl.value =
        (_expandCtrl.value + delta * sensitivity / screenH).clamp(0.0, 1.0);
  }

  void _onVerticalDragEnd(DragEndDetails d) {
    final vy = d.velocity.pixelsPerSecond.dy;
    // Seuil plus élevé (400 px/s) pour éviter les fermetures accidentelles
    if (vy > 400 || _expandCtrl.value < 0.35) {
      _collapse();
    } else {
      _expand();
    }
  }

  // ── Swipe horizontal artwork (Apple Music parallaxe) ─────────────────────────

  void _onArtworkDragUpdate(DragUpdateDetails d) {
    _isDragging = true;
    final artW = (MediaQuery.sizeOf(context).width - 64).clamp(200.0, 320.0);
    _swipeCtrl.value =
        (_swipeCtrl.value + d.delta.dx / artW).clamp(-1.0, 1.0);
  }

  void _onArtworkDragEnd(DragEndDetails d, SonLiteAudioHandler handler) {
    _isDragging = false;
    final vx = d.velocity.pixelsPerSecond.dx;
    final v = _swipeCtrl.value;

    if (vx < -500 || v < -0.35) {
      setState(() => _swipeDirection = 1);
      _swipeCtrl
          .animateTo(-1.0,
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeIn)
          .then((_) {
        handler.skipToNext();
        // TickerFuture.then() se déclenche aussi si l'animation est interrompue
        // par un nouveau drag (qui appelle .value= directement). On ne remet
        // à zéro que si aucun drag n'est en cours, sinon l'artwork snappe
        // à 0 pendant que le doigt est encore sur l'écran.
        if (mounted && !_isDragging) _swipeCtrl.value = 0.0;
      });
    } else if (vx > 500 || v > 0.35) {
      setState(() => _swipeDirection = -1);
      _swipeCtrl
          .animateTo(1.0,
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeIn)
          .then((_) {
        handler.skipToPrevious();
        if (mounted && !_isDragging) _swipeCtrl.value = 0.0;
      });
    } else {
      _swipeCtrl.animateTo(0.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic);
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(playerExpandedProvider, (_, expanded) {
      if (expanded && _expandCtrl.value < 0.99) {
        _expandCtrl.animateTo(1.0, curve: Curves.easeOutCubic);
      } else if (!expanded) {
        // Toujours annuler toute animation en attente (y compris si le ticker
        // était suspendu par TickerMode pendant qu'une route était au-dessus).
        // Sans stop(), animateTo(1.0) paused peut reprendre au retour arrière.
        _expandCtrl.stop();
        _expandCtrl.value = 0.0;
      }
    });

    // Déclencheur de secours : mediaItem vient d'arriver (null → non-null)
    // et le provider dit déjà "expanded" → forcer l'expansion au frame suivant.
    ref.listen<AsyncValue<MediaItem?>>(currentMediaItemProvider, (prev, next) {
      final hadItem = prev?.valueOrNull != null;
      final hasItem = next.valueOrNull != null;
      if (!hadItem && hasItem && ref.read(playerExpandedProvider)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _expand();
        });
      }
    });

    final mediaItem = ref.watch(currentMediaItemProvider).valueOrNull;
    if (mediaItem == null) return const SizedBox.shrink();

    final mq = MediaQuery.of(context);
    final screenH = mq.size.height;
    final screenW = mq.size.width;
    final safeBottom = mq.padding.bottom;
    final navH = widget.navBarOffset + safeBottom;

    return AnimatedBuilder(
      animation: Listenable.merge([_expandCtrl, _swipeCtrl]),
      builder: (context, _) {
        final t = _expandCtrl.value;
        final swipe = _swipeCtrl.value;
        final height = ui.lerpDouble(_kMiniHeight, screenH, t)!;
        final bottom = ui.lerpDouble(navH, 0.0, t)!;
        final radius = ui.lerpDouble(14.0, 0.0, t)!;
        final elevation = ui.lerpDouble(2.0, 0.0, t)!;

        return Positioned(
          left: 0,
          right: 0,
          bottom: bottom,
          height: height,
          // GestureDetector vertical ici, au-dessus de toute la hiérarchie.
          // Ainsi le drag ne se casse pas quand t passe la barre des 0.5
          // (avant, la ternaire mini/full swappait le widget portant le geste).
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onVerticalDragUpdate: _onVerticalDragUpdate,
            onVerticalDragEnd: _onVerticalDragEnd,
            child: _PlayerContainer(
              t: t,
              swipe: swipe,
              swipeDirection: _swipeDirection,
              screenW: screenW,
              radius: radius,
              elevation: elevation,
              mediaItem: mediaItem,
              onTapMini: _expand,
              onArtworkDragUpdate: _onArtworkDragUpdate,
              onArtworkDragEnd: _onArtworkDragEnd,
              onCollapse: _collapse,
            ),
          ),
        );
      },
    );
  }
}

// ─── Conteneur avec fond et forme ────────────────────────────────────────────

class _PlayerContainer extends ConsumerWidget {
  final double t;
  final double swipe;
  final int swipeDirection;
  final double screenW;
  final double radius;
  final double elevation;
  final MediaItem mediaItem;
  final VoidCallback onTapMini;
  final GestureDragUpdateCallback onArtworkDragUpdate;
  final void Function(DragEndDetails, SonLiteAudioHandler) onArtworkDragEnd;
  final VoidCallback onCollapse;

  const _PlayerContainer({
    required this.t,
    required this.swipe,
    required this.swipeDirection,
    required this.screenW,
    required this.radius,
    required this.elevation,
    required this.mediaItem,
    required this.onTapMini,
    required this.onArtworkDragUpdate,
    required this.onArtworkDragEnd,
    required this.onCollapse,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handler = ref.read(audioHandlerProvider);
    final cs = Theme.of(context).colorScheme;
    final bgColor = Color.lerp(cs.surfaceContainerHigh, cs.surface, t)!;

    return Material(
      elevation: elevation,
      color: bgColor,
      borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
      clipBehavior: Clip.antiAlias,
      // Pas de GestureDetector vertical ici : géré par le parent Positioned.
      // Le tap mini est séparé car il ne doit pas interférer avec le drag.
      child: t < 0.5
          ? GestureDetector(
              onTap: onTapMini,
              child: _MiniContent(item: mediaItem),
            )
          : _FullContent(
              item: mediaItem,
              t: t,
              swipe: swipe,
              swipeDirection: swipeDirection,
              screenW: screenW,
              onCollapse: onCollapse,
              onArtworkDragUpdate: onArtworkDragUpdate,
              onArtworkDragEnd: (d) => onArtworkDragEnd(d, handler),
            ),
    );
  }
}

// ─── Mode mini ────────────────────────────────────────────────────────────────

class _MiniContent extends ConsumerWidget {
  final MediaItem item;
  const _MiniContent({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playbackAsync = ref.watch(playbackStateProvider);
    final isPlaying = playbackAsync.valueOrNull?.playing ?? false;
    final handler = ref.read(audioHandlerProvider);
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: _ArtImage(artUri: item.artUri, size: 44),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.artist != null && item.artist!.isNotEmpty)
                  Text(
                    item.artist!,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow,
                color: cs.onSurface),
            onPressed: isPlaying ? handler.pause : handler.play,
          ),
          IconButton(
            icon: Icon(Icons.skip_next, color: cs.onSurface),
            onPressed: handler.skipToNext,
          ),
        ],
      ),
    );
  }
}

// ─── Mode plein écran ─────────────────────────────────────────────────────────

class _FullContent extends ConsumerWidget {
  final MediaItem item;
  final double t;
  final double swipe;
  final int swipeDirection;
  final double screenW;
  final VoidCallback onCollapse;
  final GestureDragUpdateCallback onArtworkDragUpdate;
  final GestureDragEndCallback onArtworkDragEnd;

  const _FullContent({
    required this.item,
    required this.t,
    required this.swipe,
    required this.swipeDirection,
    required this.screenW,
    required this.onCollapse,
    required this.onArtworkDragUpdate,
    required this.onArtworkDragEnd,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handler = ref.read(audioHandlerProvider);
    final playbackState = ref.watch(playbackStateProvider).valueOrNull;
    final isPlaying = playbackState?.playing ?? false;
    final position = ref.watch(audioPositionProvider).valueOrNull ?? Duration.zero;
    final duration = item.duration ?? Duration.zero;
    final loopState = ref.watch(loopStateProvider).valueOrNull ?? handler.loopState;
    final shuffle = ref.watch(shuffleEnabledProvider).valueOrNull ?? false;

    final queue = ref.watch(audioQueueProvider).valueOrNull ?? const [];
    final idx = queue.indexWhere((e) => e.id == item.id);
    final prevItem = idx > 0 ? queue[idx - 1] : null;
    final nextItem = idx >= 0 && idx < queue.length - 1 ? queue[idx + 1] : null;

    final contentOpacity = ((t - 0.5) * 2).clamp(0.0, 1.0);
    final artW = (screenW - 64).clamp(200.0, 320.0);

    // Offset courant : suit le doigt directement (swipe ∈ [-1, 1])
    final currentOffset = swipe * artW;
    // Artwork précédent : toujours à gauche du courant
    final prevOffset = currentOffset - artW - 16;
    // Artwork suivant : toujours à droite du courant
    final nextOffset = currentOffset + artW + 16;
    // Titre : parallaxe à 30% de la vitesse de l'artwork
    final titleOffset = swipe * artW * 0.3;
    final titleOpacity = (1.0 - swipe.abs() * 1.5).clamp(0.0, 1.0);

    final safeBottom = MediaQuery.paddingOf(context).bottom;

    return Opacity(
      opacity: contentOpacity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Zone supérieure : un seul GestureDetector pleine largeur ────
          // Couvre header + artwork + titre sur toute la surface disponible.
          // HitTestBehavior.translucent laisse passer les taps aux boutons enfants.
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragUpdate: onArtworkDragUpdate,
              onHorizontalDragEnd: onArtworkDragEnd,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 4),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.keyboard_arrow_down),
                          tooltip: 'Réduire',
                          onPressed: onCollapse,
                        ),
                        Expanded(
                          child: Center(
                            child: Container(
                              width: 36,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant
                                    .withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                        _MenuButton(item: item),
                      ],
                    ),
                  ),

                  // Artwork
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: SizedBox(
                      height: artW,
                      child: ClipRect(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (prevItem != null)
                              Transform.translate(
                                offset: Offset(prevOffset, 0),
                                child: _ArtworkCard(item: prevItem, size: artW),
                              ),
                            Transform.translate(
                              offset: Offset(currentOffset, 0),
                              child: _ArtworkCard(item: item, size: artW),
                            ),
                            if (nextItem != null)
                              Transform.translate(
                                offset: Offset(nextOffset, 0),
                                child: _ArtworkCard(item: nextItem, size: artW),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Titre / artiste
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        transitionBuilder: (child, anim) => SlideTransition(
                          position: Tween<Offset>(
                            begin: Offset(swipeDirection.toDouble(), 0),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(
                              parent: anim, curve: Curves.easeOutCubic)),
                          child: FadeTransition(opacity: anim, child: child),
                        ),
                        child: Transform.translate(
                          key: ValueKey(item.id),
                          offset: Offset(titleOffset, 0),
                          child: Opacity(
                            opacity: titleOpacity,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  item.title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.artist ?? '',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Contrôles fixes en bas ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: PlayerPositionSlider(
              position: position,
              duration: duration,
              onSeek: handler.seek,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_fmt(position),
                    style: Theme.of(context).textTheme.bodySmall),
                Text(_fmt(duration),
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
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
                    icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
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
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PlayerRepeatButton(
                loopState: loopState,
                onTap: handler.cycleTrackLoop,
              ),
              const SizedBox(width: 24),
              IconButton(
                icon: Icon(
                  Icons.shuffle,
                  color: shuffle
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                onPressed: () => handler.setShuffle(!shuffle),
              ),
            ],
          ),
          SizedBox(height: safeBottom + 8),
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

// ─── Bouton menu contextuel ───────────────────────────────────────────────────

class _MenuButton extends ConsumerWidget {
  final MediaItem item;
  const _MenuButton({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handler = ref.read(audioHandlerProvider);
    final trackId = item.extras?['trackId'] as int?;

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (v) => _handle(v, context, ref, handler, trackId),
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'edit', child: Text('Éditer')),
        PopupMenuItem(value: 'change_image', child: Text("Changer l'image")),
        PopupMenuItem(value: 'add_to_playlist', child: Text('Ajouter à une playlist')),
        PopupMenuItem(value: 'loop_config', child: Text('Configurer la boucle')),
      ],
    );
  }

  Future<void> _handle(String action, BuildContext ctx, WidgetRef ref,
      SonLiteAudioHandler handler, int? trackId) async {
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
}

// ─── Artwork avec ombre ───────────────────────────────────────────────────────

class _ArtworkCard extends StatelessWidget {
  final MediaItem item;
  final double size;
  const _ArtworkCard({required this.item, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: _ArtImage(artUri: item.artUri, size: size),
      ),
    );
  }
}

// ─── Image artwork (local file ou placeholder) ────────────────────────────────

class _ArtImage extends StatelessWidget {
  final Uri? artUri;
  final double size;
  const _ArtImage({required this.artUri, required this.size});

  @override
  Widget build(BuildContext context) {
    if (artUri != null) {
      return Image.file(
        File(artUri!.toFilePath()),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _placeholder(context),
      );
    }
    return _placeholder(context);
  }

  Widget _placeholder(BuildContext context) => Container(
        width: size,
        height: size,
        color: Theme.of(context).colorScheme.primaryContainer,
        child: Icon(
          Icons.music_note,
          size: size * 0.4,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      );
}
