import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/services/log_service.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  late List<LogEntry> _entries;
  StreamSubscription<LogEntry>? _sub;
  final _scrollCtrl = ScrollController();
  LogLevel? _filter;
  bool _autoScroll = true;

  @override
  void initState() {
    super.initState();
    _entries = LogService.instance.entries.toList();
    _sub = LogService.instance.stream.listen((entry) {
      if (!mounted) return;
      setState(() => _entries.add(entry));
      if (_autoScroll) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollCtrl.hasClients) {
            _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
          }
        });
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Color _levelColor(LogLevel level, BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    switch (level) {
      case LogLevel.debug:
        return cs.onSurfaceVariant;
      case LogLevel.info:
        return cs.primary;
      case LogLevel.warn:
        return Colors.orange;
      case LogLevel.error:
        return Colors.redAccent;
    }
  }

  List<LogEntry> get _visible {
    if (_filter == null) return _entries;
    return _entries.where((e) => e.level == _filter).toList();
  }

  Future<void> _copyAll() async {
    final text = LogService.instance.exportAsText();
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logs copiés dans le presse-papiers')),
    );
  }

  void _clear() {
    LogService.instance.clear();
    setState(() => _entries = []);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final visible = _visible;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Logs'),
        actions: [
          IconButton(
            tooltip: 'Copier tout',
            icon: const Icon(Icons.copy_outlined),
            onPressed: _copyAll,
          ),
          IconButton(
            tooltip: 'Effacer',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: _clear,
          ),
        ],
      ),
      body: Column(
        children: [
          // Barre de filtres
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              children: [
                _FilterChip(
                  label: 'Tous (${_entries.length})',
                  selected: _filter == null,
                  onTap: () => setState(() => _filter = null),
                ),
                ...LogLevel.values.map((lv) {
                  final count = _entries.where((e) => e.level == lv).length;
                  return _FilterChip(
                    label: '${lv.name.toUpperCase()} ($count)',
                    color: _levelColor(lv, context),
                    selected: _filter == lv,
                    onTap: () => setState(() => _filter = lv),
                  );
                }),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: visible.isEmpty
                ? Center(
                    child: Text(
                      _entries.isEmpty
                          ? 'Aucun log pour l\'instant.\nLes actions et erreurs s\'afficheront ici.'
                          : 'Aucun log à ce niveau.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    itemCount: visible.length,
                    itemBuilder: (_, i) {
                      final e = visible[i];
                      return _LogRow(entry: e, color: _levelColor(e.level, context));
                    },
                  ),
          ),
          // Bouton auto-scroll
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Switch.adaptive(
                    value: _autoScroll,
                    onChanged: (v) => setState(() => _autoScroll = v),
                  ),
                  const SizedBox(width: 8),
                  Text('Défilement automatique',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = color ?? cs.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: c.withValues(alpha: 0.18),
        labelStyle: TextStyle(
          color: selected ? c : cs.onSurfaceVariant,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          fontSize: 12,
        ),
        side: BorderSide(color: selected ? c : cs.outlineVariant),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  final LogEntry entry;
  final Color color;
  const _LogRow({required this.entry, required this.color});

  @override
  Widget build(BuildContext context) {
    final t = entry.timestamp;
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    final ss = t.second.toString().padLeft(2, '0');
    final ms = t.millisecond.toString().padLeft(3, '0');
    final time = '$hh:$mm:$ss.$ms';

    return InkWell(
      onLongPress: () async {
        await Clipboard.setData(ClipboardData(text: entry.formatLine()));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ligne copiée')),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: RichText(
          text: TextSpan(
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              height: 1.35,
            ),
            children: [
              TextSpan(
                text: '$time  ',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              TextSpan(
                text: entry.level.name.toUpperCase().padRight(5),
                style: TextStyle(color: color, fontWeight: FontWeight.w700),
              ),
              TextSpan(
                text: '  [${entry.source}] ',
                style: TextStyle(color: Theme.of(context).colorScheme.secondary),
              ),
              TextSpan(
                text: entry.message,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
