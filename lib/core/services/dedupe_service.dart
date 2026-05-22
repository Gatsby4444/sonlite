import 'dart:io';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../database/app_database.dart';
import '../database/track_repository.dart';
import 'log_service.dart';

part 'dedupe_service.g.dart';

@riverpod
DedupeService dedupeService(Ref ref) => DedupeService(ref);

/// Détecte et corrige les Track qui partagent le même filePath en base
/// (situation qui survenait quand deux téléchargements ou imports avaient
/// le même nom de fichier — cause du bug "swipe bloqué" v1.0.13).
class DedupeService {
  final Ref _ref;
  DedupeService(this._ref);

  /// Pour chaque groupe de doublons :
  ///  - garde le plus récent (id le plus grand)
  ///  - copie physiquement le fichier sous un nouveau nom pour les autres
  ///  - met à jour leur filePath en base
  /// Retourne le nombre d'entrées corrigées.
  Future<int> dedupeFilePaths() async {
    final dao = _ref.read(tracksDaoProvider);
    final tracks = await dao.getAllTracks();

    // Regroupement par filePath
    final groups = <String, List<Track>>{};
    for (final t in tracks) {
      groups.putIfAbsent(t.filePath, () => []).add(t);
    }

    int fixed = 0;
    for (final entry in groups.entries) {
      if (entry.value.length < 2) continue;
      final sharedPath = entry.key;
      appLog(
        'doublon détecté : ${entry.value.length} pistes partagent $sharedPath',
        level: LogLevel.warn,
        source: 'dedupe',
      );

      // On garde la première (l'id le plus petit = l'originale, créée en premier)
      // et on duplique le fichier pour toutes les autres.
      entry.value.sort((a, b) => a.id.compareTo(b.id));
      for (int i = 1; i < entry.value.length; i++) {
        final t = entry.value[i];
        try {
          final src = File(sharedPath);
          if (!await src.exists()) {
            appLog('source absente : $sharedPath — track #${t.id} ignorée',
                level: LogLevel.error, source: 'dedupe');
            continue;
          }
          final dir = p.dirname(sharedPath);
          final stem = p.basenameWithoutExtension(sharedPath);
          final ext = p.extension(sharedPath);
          var newPath = p.join(dir, '${stem}_dup${t.id}$ext');
          var n = 1;
          while (await File(newPath).exists()) {
            newPath = p.join(dir, '${stem}_dup${t.id}_$n$ext');
            n++;
          }
          await src.copy(newPath);
          await dao.updateTrack(
            t.toCompanion(false).copyWith(filePath: Value(newPath)),
          );
          fixed++;
          appLog('track #${t.id} (${t.title}) → $newPath',
              level: LogLevel.info, source: 'dedupe');
        } catch (e) {
          appLog('échec dédoublonnage track #${t.id} : $e',
              level: LogLevel.error, source: 'dedupe');
        }
      }
    }

    if (fixed > 0) {
      appLog('$fixed entrée(s) corrigée(s)',
          level: LogLevel.info, source: 'dedupe');
      _ref.invalidate(trackRepositoryProvider);
    } else {
      appLog('aucun doublon de filePath détecté',
          level: LogLevel.debug, source: 'dedupe');
    }
    return fixed;
  }
}

