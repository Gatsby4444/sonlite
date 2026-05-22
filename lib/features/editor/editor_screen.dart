import 'dart:async';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/track_repository.dart';
import '../../core/services/audio_editor_service.dart';
import '../../core/services/import_service.dart';
import 'widgets/audio_timeline.dart';

class EditorScreen extends ConsumerStatefulWidget {
  final int trackId;
  const EditorScreen({super.key, required this.trackId});

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  late PlayerController _waveCtrl;
  StreamSubscription<int>? _playheadSub;
  final ValueNotifier<int> _playheadNotifier = ValueNotifier(0);

  Track? _track;
  bool _playerReady = false;
  bool _loading = false;
  String? _status;

  Duration _selStart = Duration.zero;
  Duration _selEnd = Duration.zero;
  List<Duration> _markers = [];

  @override
  void initState() {
    super.initState();
    _waveCtrl = PlayerController();
    _loadTrack();
  }

  @override
  void dispose() {
    _playheadSub?.cancel();
    _waveCtrl.stopPlayer();
    _waveCtrl.dispose();
    _playheadNotifier.dispose();
    super.dispose();
  }

  Duration get _total => Duration(milliseconds: _track?.durationMs ?? 0);

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final cs =
        (d.inMilliseconds.remainder(1000) ~/ 10).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s.$cs' : '$m:$s.$cs';
  }

  Future<void> _loadTrack() async {
    final track =
        await ref.read(tracksDaoProvider).getTrackById(widget.trackId);
    if (!mounted || track == null) return;
    setState(() {
      _track = track;
      _selStart = Duration.zero;
      _selEnd = Duration(milliseconds: track.durationMs);
    });
    await _initPlayer(track.filePath);
  }

  Future<void> _initPlayer(String path) async {
    try {
      await _waveCtrl.preparePlayer(path: path, noOfSamples: 500, volume: 1.0);
      // Synchronise le curseur visuel avec la position de lecture en temps réel
      _playheadSub = _waveCtrl.onCurrentDurationChanged.listen((ms) {
        if (mounted) _playheadNotifier.value = ms;
      }, cancelOnError: true);
      if (mounted) setState(() => _playerReady = true);
    } catch (_) {}
  }

  // ─── Marqueurs ───────────────────────────────────────────────────────────────

  void _addMarkerAtPlayhead() {
    final marker = Duration(milliseconds: _playheadNotifier.value);
    if (!_markers.any((m) => (m - marker).abs() < const Duration(milliseconds: 100))) {
      setState(() => _markers = [..._markers, marker]..sort());
    }
  }

  void _removeMarker(Duration marker) {
    setState(() => _markers =
        _markers.where((m) => (m - marker).abs() >= const Duration(milliseconds: 100)).toList());
  }

  // ─── Actions ─────────────────────────────────────────────────────────────────

  void _createCopy() {
    if (!_playerReady) return;
    showDialog(
      context: context,
      builder: (_) => _NameDialog(
        defaultName: _track!.title,
        onConfirm: _extractRegion,
      ),
    );
  }

  Future<void> _extractRegion(String name) async {
    final track = _track!;
    await _waveCtrl.pausePlayer();
    setState(() {
      _loading = true;
      _status = 'Découpe en cours…';
    });
    try {
      final outPath = await ref.read(audioEditorServiceProvider).trim(
            inputPath: track.filePath,
            start: _selStart,
            end: _selEnd,
            outputName: name,
          );
      if (outPath != null) {
        await ref.read(importServiceProvider).importFromPath(outPath);
        _showStatus('« $name » ajouté à la bibliothèque');
      } else {
        _showStatus('Erreur FFmpeg — export échoué');
      }
    } catch (e) {
      _showStatus('Erreur : $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _showStatus(String msg) {
    setState(() => _status = msg);
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _status = null);
    });
  }

  // ─── Sous-widgets partagés ────────────────────────────────────────────────

  Widget _buildTimeline() {
    if (!_playerReady) {
      return Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    return AudioTimeline(
      total: _total,
      selStart: _selStart,
      selEnd: _selEnd,
      playheadNotifier: _playheadNotifier,
      markers: _markers,
      onSelStartChanged: (d) => setState(() => _selStart = d),
      onSelEndChanged: (d) => setState(() => _selEnd = d),
      onSeek: (d) => _waveCtrl.seekTo(d.inMilliseconds),
      onMarkerTapped: _removeMarker,
    );
  }

  Widget _buildControls(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final selDuration = _selEnd - _selStart;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Lecteur ──────────────────────────────────────────────────────
        _MiniPlayer(
          controller: _waveCtrl,
          total: _total,
          fmt: _fmt,
          onAddMarker: _playerReady ? _addMarkerAtPlayhead : null,
          markerCount: _markers.length,
        ),

        const Divider(height: 1),

        // ── Info sélection ────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(
                '[  ${_fmt(_selStart)}',
                style: TextStyle(
                  color: cs.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _fmt(selDuration),
                  style: TextStyle(
                    color: cs.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${_fmt(_selEnd)}  ]',
                style: TextStyle(
                  color: cs.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),

        const Divider(height: 1),

        // ── Bouton principal ──────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: FilledButton.icon(
            icon: const Icon(Icons.file_copy_outlined),
            label: const Text('Créer une copie de la sélection'),
            onPressed: _playerReady && !_loading ? _createCopy : null,
          ),
        ),
      ],
    );
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_track == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Éditeur')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title:
            Text(_track!.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // ── Layout responsive ────────────────────────────────────────
            OrientationBuilder(builder: (context, orientation) {
              if (orientation == Orientation.landscape) {
                // Paysage : timeline à gauche, contrôles à droite
                return Row(
                  children: [
                    Expanded(child: _buildTimeline()),
                    const VerticalDivider(width: 1),
                    SizedBox(
                      width: 240,
                      child: SingleChildScrollView(
                        child: _buildControls(context),
                      ),
                    ),
                  ],
                );
              }

              // Portrait : timeline en haut (hauteur fixe adaptée)
              return Column(
                children: [
                  _TimelineArea(child: _buildTimeline()),
                  Expanded(
                    child: SingleChildScrollView(
                      child: _buildControls(context),
                    ),
                  ),
                ],
              );
            }),

            // ── Loading overlay ──────────────────────────────────────────
            if (_loading)
              Container(
                color: Colors.black54,
                child: const Center(child: CircularProgressIndicator()),
              ),

            // ── Statut ───────────────────────────────────────────────────
            if (_status != null)
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(10),
                  color: Theme.of(context).colorScheme.inverseSurface,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Text(
                      _status!,
                      style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onInverseSurface),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Hauteur de la timeline en portrait ──────────────────────────────────────

/// Donne à la timeline une hauteur proportionnelle à l'écran,
/// entre 150 et 280 px.
class _TimelineArea extends StatelessWidget {
  final Widget child;
  const _TimelineArea({required this.child});

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final h = (screenH * 0.3).clamp(150.0, 280.0);
    return SizedBox(height: h, child: child);
  }
}

// ─── Dialog nommage ───────────────────────────────────────────────────────────

class _NameDialog extends StatefulWidget {
  final String defaultName;
  final ValueChanged<String> onConfirm;
  const _NameDialog({required this.defaultName, required this.onConfirm});

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.defaultName);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _confirm() {
    final name = _ctrl.text.trim();
    if (name.isNotEmpty) {
      Navigator.pop(context);
      widget.onConfirm(name);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nommer la copie'),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Titre du nouveau morceau',
          border: OutlineInputBorder(),
        ),
        onSubmitted: (_) => _confirm(),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler')),
        FilledButton(onPressed: _confirm, child: const Text('Créer')),
      ],
    );
  }
}

// ─── Mini-lecteur ─────────────────────────────────────────────────────────────

class _MiniPlayer extends StatelessWidget {
  final PlayerController controller;
  final Duration total;
  final String Function(Duration) fmt;
  final VoidCallback? onAddMarker;
  final int markerCount;

  const _MiniPlayer({
    required this.controller,
    required this.total,
    required this.fmt,
    required this.onAddMarker,
    required this.markerCount,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return StreamBuilder<PlayerState>(
      stream: controller.onPlayerStateChanged,
      builder: (ctx, stateSnap) {
        final playing = stateSnap.data == PlayerState.playing;
        return Row(
          children: [
            // Play/Pause
            IconButton(
              icon: Icon(
                playing ? Icons.pause_circle : Icons.play_circle,
                size: 36,
                color: cs.primary,
              ),
              onPressed: () async {
                if (playing) {
                  await controller.pausePlayer();
                } else {
                  await controller.startPlayer();
                }
              },
            ),

            // Position
            Expanded(
              child: StreamBuilder<int>(
                stream: controller.onCurrentDurationChanged,
                builder: (_, posSnap) {
                  final ms = posSnap.data ?? 0;
                  return Text(
                    '${fmt(Duration(milliseconds: ms))} / ${fmt(total)}',
                    style: Theme.of(ctx).textTheme.bodySmall,
                  );
                },
              ),
            ),

            // Bouton marqueur
            Tooltip(
              message: markerCount > 0
                  ? 'Ajouter un marqueur ($markerCount)\nTap sur un marqueur pour le supprimer'
                  : 'Ajouter un marqueur au playhead',
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: onAddMarker,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.bookmark_add_outlined,
                        size: 20,
                        color: onAddMarker != null
                            ? Colors.red
                            : Theme.of(ctx).disabledColor,
                      ),
                      if (markerCount > 0) ...[
                        const SizedBox(width: 3),
                        Text(
                          '$markerCount',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.red,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
        );
      },
    );
  }
}
