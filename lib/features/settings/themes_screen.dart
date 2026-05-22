import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/theme_provider.dart';

class ThemesScreen extends ConsumerWidget {
  const ThemesScreen({super.key});

  static const _palette = [
    _ColorOption('Violet', Color(0xFF6750A4)),
    _ColorOption('Bleu', Color(0xFF1565C0)),
    _ColorOption('Indigo', Color(0xFF283593)),
    _ColorOption('Cyan', Color(0xFF00838F)),
    _ColorOption('Teal', Color(0xFF00695C)),
    _ColorOption('Vert', Color(0xFF2E7D32)),
    _ColorOption('Lime', Color(0xFF558B2F)),
    _ColorOption('Ambre', Color(0xFFFF8F00)),
    _ColorOption('Orange', Color(0xFFE65100)),
    _ColorOption('Rouge', Color(0xFFC62828)),
    _ColorOption('Rose', Color(0xFFAD1457)),
    _ColorOption('Fuchsia', Color(0xFF6A1B9A)),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(themeColorProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Thèmes')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Couleur de l\'interface',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Personnalise la couleur des boutons et des accents.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.85,
            ),
            itemCount: _palette.length,
            itemBuilder: (context, i) {
              final opt = _palette[i];
              final isSelected = current.toARGB32() == opt.color.toARGB32();
              return _ColorChip(
                option: opt,
                selected: isSelected,
                onTap: () =>
                    ref.read(themeColorProvider.notifier).setColor(opt.color),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ColorChip extends StatelessWidget {
  final _ColorOption option;
  final bool selected;
  final VoidCallback onTap;

  const _ColorChip({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: option.color,
              shape: BoxShape.circle,
              border: selected
                  ? Border.all(color: Colors.white, width: 3)
                  : Border.all(color: Colors.transparent, width: 3),
              boxShadow: selected
                  ? [
                      BoxShadow(
                          color: option.color.withValues(alpha: 0.6),
                          blurRadius: 10,
                          spreadRadius: 2)
                    ]
                  : null,
            ),
            child: selected
                ? const Icon(Icons.check, color: Colors.white, size: 26)
                : null,
          ),
          const SizedBox(height: 6),
          Text(
            option.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorOption {
  final String label;
  final Color color;
  const _ColorOption(this.label, this.color);
}
