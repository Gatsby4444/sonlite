import 'package:flutter/material.dart';

class PlayerPositionSlider extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;
  const PlayerPositionSlider(
      {super.key,
      required this.position,
      required this.duration,
      required this.onSeek});

  @override
  State<PlayerPositionSlider> createState() => _PlayerPositionSliderState();
}

class _PlayerPositionSliderState extends State<PlayerPositionSlider> {
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
