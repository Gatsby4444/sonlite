import 'dart:math';
import 'package:flutter/material.dart';

enum _Handle { none, start, end, playhead }

/// Timeline simple (sans waveform) pour l'éditeur audio.
///
/// Gestes (ScaleRecognizer uniquement, pas de TapRecognizer concurrent) :
///   • 2 doigts   → pinch-to-zoom ancré au point focal
///   • 1 doigt sur [ → déplace le curseur de début
///   • 1 doigt sur ] → déplace le curseur de fin
///   • 1 doigt sur ▼ (playhead) → déplace la tête de lecture
///   • 1 doigt ailleurs → scroll horizontal
///   • tap (< 6 px) → seek ou supprime un marqueur
class AudioTimeline extends StatefulWidget {
  final Duration total;
  final Duration selStart;
  final Duration selEnd;
  final ValueNotifier<int> playheadNotifier;
  final List<Duration> markers;
  final ValueChanged<Duration>? onSelStartChanged;
  final ValueChanged<Duration>? onSelEndChanged;
  final ValueChanged<Duration>? onSeek;
  final ValueChanged<Duration>? onMarkerTapped;

  const AudioTimeline({
    super.key,
    required this.total,
    required this.selStart,
    required this.selEnd,
    required this.playheadNotifier,
    this.markers = const [],
    this.onSelStartChanged,
    this.onSelEndChanged,
    this.onSeek,
    this.onMarkerTapped,
  });

  @override
  State<AudioTimeline> createState() => _AudioTimelineState();
}

class _AudioTimelineState extends State<AudioTimeline> {
  static const double _rulerH = 22.0;
  static const double _basePxPerSec = 60.0;
  static const double _maxZoom = 80.0;

  double _zoom = 1.0;
  double _scroll = 0.0;
  double _viewW = 300.0;
  bool _initialized = false;

  double _lastScale = 1.0;
  _Handle _dragMode = _Handle.none;
  Offset? _gestureStartPos;
  bool _gestureWasDrag = false;

  Duration _playhead = Duration.zero;

  // ─── Zoom dynamique ──────────────────────────────────────────────────────────

  double get _fitZoom {
    if (widget.total.inMilliseconds <= 0 || _viewW <= 0) return 1.0;
    return _viewW / (widget.total.inMilliseconds / 1000.0 * _basePxPerSec);
  }

  double get _minZoom => max(0.0001, _fitZoom * 0.8);

  // ─── Lifecycle ───────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    widget.playheadNotifier.addListener(_onPlayheadChanged);
  }

  @override
  void didUpdateWidget(AudioTimeline old) {
    super.didUpdateWidget(old);
    if (old.playheadNotifier != widget.playheadNotifier) {
      old.playheadNotifier.removeListener(_onPlayheadChanged);
      widget.playheadNotifier.addListener(_onPlayheadChanged);
    }
  }

  @override
  void dispose() {
    widget.playheadNotifier.removeListener(_onPlayheadChanged);
    super.dispose();
  }

  void _onPlayheadChanged() {
    if (!mounted) return;
    final newHead = Duration(milliseconds: widget.playheadNotifier.value);
    final localX = _durToLocal(newHead);
    setState(() {
      _playhead = newHead;
      if (localX < 40) {
        _scroll = max(0, _durToFullX(newHead) - 40);
      } else if (localX > _viewW - 40) {
        _scroll = min(_maxScroll, _durToFullX(newHead) - _viewW + 40);
      }
    });
  }

  // ─── Conversions ─────────────────────────────────────────────────────────────

  double get _scale => _basePxPerSec * _zoom;
  double get _timelineW =>
      max(_viewW, widget.total.inMilliseconds / 1000.0 * _scale);
  double get _maxScroll => max(0.0, _timelineW - _viewW);

  double _durToFullX(Duration d) => d.inMilliseconds / 1000.0 * _scale;
  double _durToLocal(Duration d) => _durToFullX(d) - _scroll;

  Duration _localToDur(double localX) {
    final ms = ((localX + _scroll) / _scale * 1000)
        .round()
        .clamp(0, widget.total.inMilliseconds);
    return Duration(milliseconds: ms);
  }

  // ─── Gestes ──────────────────────────────────────────────────────────────────

  void _onScaleStart(ScaleStartDetails d) {
    _lastScale = 1.0;
    _dragMode = _Handle.none;
    _gestureWasDrag = false;
    _gestureStartPos = d.localFocalPoint;

    if (d.pointerCount == 1) {
      final x = d.localFocalPoint.dx;
      final sx = _durToLocal(widget.selStart);
      final ex = _durToLocal(widget.selEnd);
      final px = _durToLocal(_playhead);

      if ((x - sx).abs() <= 32) {
        _dragMode = _Handle.start;
      } else if ((x - ex).abs() <= 32) {
        _dragMode = _Handle.end;
      } else if ((x - px).abs() <= 24) {
        _dragMode = _Handle.playhead;
      }
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    if (_gestureStartPos != null &&
        (d.localFocalPoint - _gestureStartPos!).distance > 6) {
      _gestureWasDrag = true;
    }

    setState(() {
      if (d.pointerCount >= 2) {
        final scaleChange = d.scale / _lastScale;
        _lastScale = d.scale;
        final focalFull = d.localFocalPoint.dx + _scroll;
        _zoom = (_zoom * scaleChange).clamp(_minZoom, _maxZoom);
        _scroll = (focalFull - d.localFocalPoint.dx).clamp(0.0, _maxScroll);
      } else if (_dragMode == _Handle.start) {
        final dur = _localToDur(d.localFocalPoint.dx);
        if (dur < widget.selEnd - const Duration(milliseconds: 200)) {
          widget.onSelStartChanged?.call(dur);
        }
      } else if (_dragMode == _Handle.end) {
        final dur = _localToDur(d.localFocalPoint.dx);
        if (dur > widget.selStart + const Duration(milliseconds: 200)) {
          widget.onSelEndChanged?.call(dur);
        }
      } else if (_dragMode == _Handle.playhead) {
        final dur = _localToDur(d.localFocalPoint.dx);
        widget.onSeek?.call(dur);
      } else {
        _scroll = (_scroll - d.focalPointDelta.dx).clamp(0.0, _maxScroll);
      }
    });
  }

  void _onScaleEnd(ScaleEndDetails _) {
    if (!_gestureWasDrag && _dragMode == _Handle.none) {
      final tapX = _gestureStartPos?.dx;
      if (tapX != null) {
        for (final marker in widget.markers) {
          final mx = _durToLocal(marker);
          if ((tapX - mx).abs() <= 14) {
            widget.onMarkerTapped?.call(marker);
            _gestureStartPos = null;
            return;
          }
        }
        widget.onSeek?.call(_localToDur(tapX));
      }
    }
    _dragMode = _Handle.none;
    _gestureStartPos = null;
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return LayoutBuilder(builder: (ctx, box) {
      _viewW = box.maxWidth;

      if (!_initialized && _viewW > 0 && widget.total.inMilliseconds > 0) {
        _initialized = true;
        _zoom = _fitZoom.clamp(_minZoom, _maxZoom);
      }

      final trackH = max(0.0, box.maxHeight - _rulerH);

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        onScaleEnd: _onScaleEnd,
        child: ClipRect(
          child: SizedBox.expand(
            child: Stack(
              children: [
                // ── Fond ─────────────────────────────────────────────────
                Positioned.fill(
                  child: ColoredBox(color: cs.surfaceContainerHighest),
                ),

                // ── Piste audio (bande simple) ────────────────────────────
                Positioned(
                  top: _rulerH,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: CustomPaint(
                    painter: _TrackPainter(
                      scale: _scale,
                      scroll: _scroll,
                      totalMs: widget.total.inMilliseconds,
                      trackColor: cs.primary.withValues(alpha: 0.18),
                      borderColor: cs.primary.withValues(alpha: 0.35),
                    ),
                  ),
                ),

                // ── Règle temporelle ──────────────────────────────────────
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: _rulerH,
                  child: CustomPaint(
                    painter: _RulerPainter(
                      scale: _scale,
                      scroll: _scroll,
                      totalMs: widget.total.inMilliseconds,
                      textColor: cs.onSurfaceVariant,
                      tickColor: cs.outlineVariant,
                    ),
                  ),
                ),

                // ── Overlay : sélection, marqueurs, playhead ──────────────
                Positioned(
                  top: _rulerH,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: CustomPaint(
                    painter: _OverlayPainter(
                      selStart: widget.selStart,
                      selEnd: widget.selEnd,
                      total: widget.total,
                      markers: widget.markers,
                      playhead: _playhead,
                      scroll: _scroll,
                      scale: _scale,
                      primaryColor: cs.primary,
                      viewW: _viewW,
                      trackH: trackH,
                    ),
                  ),
                ),

                // ── Indicateur de zoom ────────────────────────────────────
                Positioned(
                  bottom: 3,
                  right: 6,
                  child: Text(
                    '${_zoom >= 1 ? _zoom.toStringAsFixed(1) : _zoom.toStringAsFixed(2)}×',
                    style: TextStyle(
                      fontSize: 9,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

// ─── Bande de piste ───────────────────────────────────────────────────────────

class _TrackPainter extends CustomPainter {
  final double scale;
  final double scroll;
  final int totalMs;
  final Color trackColor;
  final Color borderColor;

  const _TrackPainter({
    required this.scale,
    required this.scroll,
    required this.totalMs,
    required this.trackColor,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (totalMs <= 0) return;
    final trackW = totalMs / 1000.0 * scale;
    final left = -scroll;
    final right = left + trackW;
    final cl = left.clamp(0.0, size.width);
    final cr = right.clamp(0.0, size.width);
    if (cr <= cl) return;

    final bandTop = size.height * 0.2;
    final bandBot = size.height * 0.8;

    final rect = Rect.fromLTRB(cl, bandTop, cr, bandBot);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      Paint()..color = trackColor,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_TrackPainter old) =>
      old.scale != scale || old.scroll != scroll;
}

// ─── Règle temporelle ─────────────────────────────────────────────────────────

class _RulerPainter extends CustomPainter {
  final double scale;
  final double scroll;
  final int totalMs;
  final Color textColor;
  final Color tickColor;

  const _RulerPainter({
    required this.scale,
    required this.scroll,
    required this.totalMs,
    required this.textColor,
    required this.tickColor,
  });

  double _interval() {
    const target = 80.0;
    final s = target / scale;
    if (s < 0.1) return 0.05;
    if (s < 0.3) return 0.1;
    if (s < 0.75) return 0.5;
    if (s < 3) return 1.0;
    if (s < 7) return 2.0;
    if (s < 15) return 5.0;
    if (s < 45) return 10.0;
    if (s < 90) return 30.0;
    if (s < 240) return 60.0;
    if (s < 600) return 120.0;
    if (s < 1800) return 300.0;
    return 600.0;
  }

  String _label(double secs) {
    final d = Duration(milliseconds: (secs * 1000).round());
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (h > 0) return '$h:$m:$s';
    if (_interval() < 1.0) {
      final tenths = ((secs * 10).round() % 10);
      return '${d.inSeconds}.$tenths';
    }
    return '$m:$s';
  }

  @override
  void paint(Canvas canvas, Size size) {
    final interval = _interval();
    final intervalPx = interval * scale;
    if (intervalPx < 1) return;

    final tickPaint = Paint()
      ..color = tickColor
      ..strokeWidth = 1;

    final firstSec = scroll / scale;
    final firstTick = (firstSec / interval).ceil() * interval;
    var x = firstTick * scale - scroll;

    while (x <= size.width + 1) {
      final secs = (x + scroll) / scale;
      if (secs <= totalMs / 1000.0 + 0.01) {
        canvas.drawLine(
            Offset(x, size.height - 7), Offset(x, size.height), tickPaint);
        final tp = TextPainter(
          text: TextSpan(
            text: _label(secs),
            style: TextStyle(color: textColor, fontSize: 9),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: intervalPx * 0.85);
        tp.paint(canvas, Offset(x - tp.width / 2, 3));
      }
      x += intervalPx;
    }
  }

  @override
  bool shouldRepaint(_RulerPainter old) =>
      old.scale != scale || old.scroll != scroll;
}

// ─── Overlay ──────────────────────────────────────────────────────────────────

class _OverlayPainter extends CustomPainter {
  final Duration selStart;
  final Duration selEnd;
  final Duration total;
  final List<Duration> markers;
  final Duration playhead;
  final double scroll;
  final double scale;
  final Color primaryColor;
  final double viewW;
  final double trackH;

  _OverlayPainter({
    required this.selStart,
    required this.selEnd,
    required this.total,
    required this.markers,
    required this.playhead,
    required this.scroll,
    required this.scale,
    required this.primaryColor,
    required this.viewW,
    required this.trackH,
  });

  double _x(Duration d) => d.inMilliseconds / 1000.0 * scale - scroll;

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    if (total == Duration.zero) return;

    final sx = _x(selStart);
    final ex = _x(selEnd);

    // ── Zones assombries hors sélection ──────────────────────────────────
    final dim = Paint()..color = Colors.black.withValues(alpha: 0.42);
    if (sx > 0) {
      canvas.drawRect(Rect.fromLTRB(0, 0, min(sx, viewW), h), dim);
    }
    if (ex < viewW) {
      canvas.drawRect(Rect.fromLTRB(max(ex, 0), 0, viewW, h), dim);
    }

    // ── Surbrillance sélection ────────────────────────────────────────────
    if (sx < viewW && ex > 0) {
      canvas.drawRect(
        Rect.fromLTRB(max(sx, 0), 0, min(ex, viewW), h),
        Paint()..color = primaryColor.withValues(alpha: 0.12),
      );
    }

    // ── Crochets [ et ] ───────────────────────────────────────────────────
    _drawBracket(canvas, sx, h, primaryColor, isLeft: true);
    _drawBracket(canvas, ex, h, primaryColor, isLeft: false);

    // ── Marqueurs rouges ──────────────────────────────────────────────────
    final markerPaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 1.5;

    for (final marker in markers) {
      final mx = _x(marker);
      if (mx < -16 || mx > viewW + 16) continue;
      canvas.drawLine(Offset(mx, 0), Offset(mx, h), markerPaint);
      final flag = Path()
        ..moveTo(mx, 0)
        ..lineTo(mx + 10, 0)
        ..lineTo(mx + 10, 11)
        ..lineTo(mx, 14)
        ..close();
      canvas.drawPath(flag, Paint()..color = Colors.red);
    }

    // ── Tête de lecture ───────────────────────────────────────────────────
    final px = _x(playhead);
    if (px >= 0 && px <= viewW) {
      canvas.drawLine(
        Offset(px, 0),
        Offset(px, h),
        Paint()
          ..color = Colors.white
          ..strokeWidth = 2,
      );
      final tri = Path()
        ..moveTo(px - 8, 0)
        ..lineTo(px + 8, 0)
        ..lineTo(px, 13)
        ..close();
      canvas.drawPath(tri, Paint()..color = Colors.white);
    }
  }

  void _drawBracket(
      Canvas canvas, double x, double h, Color color, {required bool isLeft}) {
    if (x < -50 || x > viewW + 50) return;
    const armLen = 14.0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.square;

    canvas.drawLine(Offset(x, 0), Offset(x, h), paint);
    if (isLeft) {
      canvas.drawLine(Offset(x, 0), Offset(x + armLen, 0), paint);
      canvas.drawLine(Offset(x, h), Offset(x + armLen, h), paint);
    } else {
      canvas.drawLine(Offset(x, 0), Offset(x - armLen, 0), paint);
      canvas.drawLine(Offset(x, h), Offset(x - armLen, h), paint);
    }
  }

  @override
  bool shouldRepaint(_OverlayPainter old) => true;
}
