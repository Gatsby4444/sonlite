import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/services/audio_handler.dart';

class LoopDialog extends StatefulWidget {
  final SonLiteAudioHandler handler;
  const LoopDialog({super.key, required this.handler});

  @override
  State<LoopDialog> createState() => _LoopDialogState();
}

class _LoopDialogState extends State<LoopDialog> {
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
