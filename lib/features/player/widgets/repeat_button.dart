import 'package:flutter/material.dart';

class PlayerRepeatButton extends StatelessWidget {
  final int loopState;
  final VoidCallback onTap;
  const PlayerRepeatButton(
      {super.key, required this.loopState, required this.onTap});

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
