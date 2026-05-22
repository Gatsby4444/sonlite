import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'log_service.dart';

part 'audio_editor_service.g.dart';

@riverpod
AudioEditorService audioEditorService(Ref ref) => AudioEditorService();

class AudioEditorService {
  static const _channel = MethodChannel('com.sonlite/audio_editor');

  Future<Directory> _exportsDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'exports'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Découpe [inputPath] entre [start] et [end] et ajoute le résultat à la
  /// bibliothèque. Retourne le chemin du fichier créé, ou null en cas d'erreur.
  /// Choisit l'extension de sortie en conservant celle de l'entrée
  /// (sauf pour .aac/.m4a → .m4a, pour rester cohérent avec MediaMuxer).
  String _outputExtFor(String inputPath) {
    final ext = p.extension(inputPath).toLowerCase();
    if (ext.isEmpty) return '.m4a';
    if (ext == '.aac') return '.m4a';
    return ext;
  }

  /// Diagnostic du fichier source (taille, MIME, entête) — utile pour les logs.
  Future<Map<String, dynamic>?> probe(String inputPath) async {
    try {
      final r = await _channel.invokeMapMethod<String, dynamic>('probe', {
        'inputPath': inputPath,
      });
      return r;
    } catch (e) {
      appLog('probe: $e', level: LogLevel.error, source: 'editor');
      return null;
    }
  }

  Future<String?> trim({
    required String inputPath,
    required Duration start,
    required Duration end,
    String? outputName,
  }) async {
    final dir = await _exportsDir();
    final name = outputName ?? p.basenameWithoutExtension(inputPath);
    final ts = DateTime.now().millisecondsSinceEpoch;
    final outPath = p.join(dir.path, '${name}_trim_$ts${_outputExtFor(inputPath)}');

    appLog('trim → ${p.basename(outPath)} '
        '[${start.inMilliseconds}ms..${end.inMilliseconds}ms]',
        source: 'editor');

    // Diagnostic en amont pour qu'on voie ce qu'on traite, même en cas d'échec
    final info = await probe(inputPath);
    if (info != null) {
      appLog('source : ext=${info['ext']} mime=${info['mime']} '
          'size=${info['size']}o',
          source: 'editor');
    }

    try {
      final result = await _channel.invokeMapMethod<String, dynamic>('trim', {
        'inputPath': inputPath,
        'startMs': start.inMilliseconds,
        'endMs': end.inMilliseconds,
        'outputPath': outPath,
      });
      final method = result?['method'] ?? 'inconnu';
      appLog('trim OK via $method', source: 'editor');
      // Sanity check : fichier réellement créé et non vide ?
      final f = File(outPath);
      if (!await f.exists() || (await f.length()) == 0) {
        appLog('trim a renvoyé OK mais le fichier est vide/absent',
            level: LogLevel.error, source: 'editor');
        return null;
      }
      return outPath;
    } on PlatformException catch (e) {
      appLog('trim ÉCHEC [${e.code}] ${e.message}',
          level: LogLevel.error, source: 'editor');
      if (e.details != null) {
        appLog('détails : ${e.details}',
            level: LogLevel.debug, source: 'editor');
      }
      // Nettoyage du fichier partiel éventuel
      try { final f = File(outPath); if (await f.exists()) await f.delete(); } catch (_) {}
      return null;
    } catch (e) {
      appLog('trim ÉCHEC inattendu : $e',
          level: LogLevel.error, source: 'editor');
      return null;
    }
  }

  /// Découpe [inputPath] en place : remplace le fichier d'origine par la
  /// sélection trimmée. Retourne la nouvelle durée (ms) en cas de succès,
  /// null sinon. Le fichier d'origine est restauré si quelque chose échoue.
  Future<int?> cropInPlace({
    required String inputPath,
    required Duration start,
    required Duration end,
  }) async {
    final src = File(inputPath);
    if (!await src.exists()) {
      appLog('cropInPlace : source absente ($inputPath)',
          level: LogLevel.error, source: 'editor');
      return null;
    }
    appLog('cropInPlace ${start.inMilliseconds}ms..${end.inMilliseconds}ms',
        source: 'editor');

    final info = await probe(inputPath);
    if (info != null) {
      appLog('source : ext=${info['ext']} mime=${info['mime']} '
          'size=${info['size']}o header=${info['header']}',
          source: 'editor');
    }

    final dir = src.parent;
    final ts = DateTime.now().millisecondsSinceEpoch;
    final ext = _outputExtFor(inputPath);
    // Pas de point initial pour éviter d'éventuels comportements liés aux
    // dotfiles sur Android.
    final tmpOut = p.join(dir.path, 'crop_tmp_$ts$ext');
    final tmpBak = p.join(dir.path, 'crop_bak_$ts$ext');

    try {
      final result = await _channel.invokeMapMethod<String, dynamic>('trim', {
        'inputPath': inputPath,
        'startMs': start.inMilliseconds,
        'endMs': end.inMilliseconds,
        'outputPath': tmpOut,
      });
      final tmp = File(tmpOut);
      if (!await tmp.exists() || (await tmp.length()) == 0) {
        appLog('cropInPlace : fichier temp vide/absent — abandon',
            level: LogLevel.error, source: 'editor');
        return null;
      }
      appLog('cropInPlace trim OK via ${result?['method']}', source: 'editor');

      await src.rename(tmpBak);
      try {
        await tmp.rename(inputPath);
      } catch (e) {
        await File(tmpBak).rename(inputPath);
        rethrow;
      }
      await File(tmpBak).delete();
      appLog('cropInPlace OK — original remplacé', source: 'editor');
      return (end - start).inMilliseconds;
    } on PlatformException catch (e) {
      appLog('cropInPlace ÉCHEC [${e.code}] ${e.message}',
          level: LogLevel.error, source: 'editor');
      if (e.details != null) {
        appLog('détails : ${e.details}',
            level: LogLevel.debug, source: 'editor');
      }
    } catch (e) {
      appLog('cropInPlace ÉCHEC : $e',
          level: LogLevel.error, source: 'editor');
    }
    try { final f = File(tmpOut); if (await f.exists()) await f.delete(); } catch (_) {}
    try {
      final bak = File(tmpBak);
      if (await bak.exists() && !await src.exists()) await bak.rename(inputPath);
    } catch (_) {}
    return null;
  }

  /// Découpe [inputPath] en plusieurs segments aux [timestamps] donnés.
  /// Retourne la liste des chemins créés (vide si erreur).
  Future<List<String>> split({
    required String inputPath,
    required List<Duration> timestamps,
    required Duration totalDuration,
  }) async {
    if (timestamps.isEmpty) return [];

    final dir = await _exportsDir();
    final baseName = p.basenameWithoutExtension(inputPath);
    final ts = DateTime.now().millisecondsSinceEpoch;

    final starts = [Duration.zero, ...timestamps];
    final ends = [...timestamps, totalDuration];

    final outputPaths = List.generate(
      starts.length,
      (i) => p.join(dir.path, '${baseName}_part${i + 1}_$ts.m4a'),
    );

    final segments = List.generate(starts.length, (i) => {
      'startMs': starts[i].inMilliseconds,
      'endMs': ends[i].inMilliseconds,
      'outputPath': outputPaths[i],
    });

    try {
      await _channel.invokeMethod<void>('split', {
        'inputPath': inputPath,
        'segments': segments,
      });
      return outputPaths.where((path) => File(path).existsSync()).toList();
    } on PlatformException catch (e) {
      debugPrint('[audio_editor] split: ${e.code} — ${e.message}');
      return [];
    }
  }

  /// Convertit [inputPath] en MP3 via FFmpeg (extrait par youtubedl-android).
  /// Retourne le chemin du fichier MP3 créé, ou null en cas d'erreur.
  Future<String?> convertToMp3(String inputPath) async {
    final dir = await _exportsDir();
    final name = p.basenameWithoutExtension(inputPath);
    final ts = DateTime.now().millisecondsSinceEpoch;
    final outPath = p.join(dir.path, '${name}_$ts.mp3');

    try {
      await _channel.invokeMethod<void>('toMp3', {
        'inputPath': inputPath,
        'outputPath': outPath,
      });
      return outPath;
    } on PlatformException catch (e) {
      debugPrint('[audio_editor] toMp3: ${e.code} — ${e.message}');
      return null;
    }
  }
}
