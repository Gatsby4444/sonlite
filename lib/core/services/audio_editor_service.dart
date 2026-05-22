import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

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

    try {
      await _channel.invokeMethod<void>('trim', {
        'inputPath': inputPath,
        'startMs': start.inMilliseconds,
        'endMs': end.inMilliseconds,
        'outputPath': outPath,
      });
      return outPath;
    } on PlatformException catch (e) {
      debugPrint('[audio_editor] trim: ${e.code} — ${e.message}');
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
      debugPrint('[audio_editor] cropInPlace: source absente');
      return null;
    }
    final dir = src.parent;
    final ts = DateTime.now().millisecondsSinceEpoch;
    final ext = _outputExtFor(inputPath);
    final tmpOut = p.join(dir.path, '.crop_tmp_$ts$ext');
    final tmpBak = p.join(dir.path, '.crop_bak_$ts$ext');

    try {
      await _channel.invokeMethod<void>('trim', {
        'inputPath': inputPath,
        'startMs': start.inMilliseconds,
        'endMs': end.inMilliseconds,
        'outputPath': tmpOut,
      });
      // Atomique : on déplace l'original en backup puis on déplace le tmp à sa place.
      await src.rename(tmpBak);
      try {
        await File(tmpOut).rename(inputPath);
      } catch (e) {
        // Restauration en cas d'échec du rename final
        await File(tmpBak).rename(inputPath);
        rethrow;
      }
      await File(tmpBak).delete();
      return (end - start).inMilliseconds;
    } on PlatformException catch (e) {
      debugPrint('[audio_editor] cropInPlace: ${e.code} — ${e.message}');
    } catch (e) {
      debugPrint('[audio_editor] cropInPlace: $e');
    }
    // Nettoyage en cas d'échec
    try { final f = File(tmpOut); if (await f.exists()) await f.delete(); } catch (_) {}
    try { final f = File(tmpBak); if (await f.exists() && !await src.exists()) await f.rename(inputPath); } catch (_) {}
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
