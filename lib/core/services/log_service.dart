import 'dart:async';
import 'package:flutter/foundation.dart';

/// Niveau d'un log — détermine la couleur affichée.
enum LogLevel { debug, info, warn, error }

class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String source;
  final String message;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.source,
    required this.message,
  });

  String formatLine() {
    final t = timestamp;
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    final ss = t.second.toString().padLeft(2, '0');
    final ms = t.millisecond.toString().padLeft(3, '0');
    return '$hh:$mm:$ss.$ms [${level.name.toUpperCase().padRight(5)}] [$source] $message';
  }
}

/// Buffer in-memory partagé par toute l'app. Voir [appLog].
class LogService {
  LogService._();
  static final LogService instance = LogService._();

  static const int _maxEntries = 1000;
  final List<LogEntry> _entries = [];
  final _controller = StreamController<LogEntry>.broadcast();

  List<LogEntry> get entries => List.unmodifiable(_entries);
  Stream<LogEntry> get stream => _controller.stream;

  void log(String message, {LogLevel level = LogLevel.info, String source = 'app'}) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      source: source,
      message: message,
    );
    _entries.add(entry);
    if (_entries.length > _maxEntries) {
      _entries.removeRange(0, _entries.length - _maxEntries);
    }
    _controller.add(entry);
    // Aussi visible dans la console pour le développement
    if (kDebugMode) debugPrint(entry.formatLine());
  }

  void clear() {
    _entries.clear();
  }

  String exportAsText() {
    return _entries.map((e) => e.formatLine()).join('\n');
  }
}

/// Helper global pour logger depuis n'importe où sans injecter LogService.
void appLog(
  String message, {
  LogLevel level = LogLevel.info,
  String source = 'app',
}) {
  LogService.instance.log(message, level: level, source: source);
}
