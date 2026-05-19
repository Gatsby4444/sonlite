import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'ffmpeg_service.g.dart';

@riverpod
FfmpegService ffmpegService(Ref ref) => FfmpegService();

class FfmpegService {
  static const _channel = MethodChannel('com.sonlite/ffmpeg');

  Future<bool> _execute(List<String> args) async {
    try {
      final rc = await _channel.invokeMethod<int>('execute', {'args': args});
      return rc == 0;
    } on PlatformException catch (e) {
      debugPrint('[ffmpeg] PlatformException: ${e.code} — ${e.message}');
      return false;
    }
  }

  /// Initialise FFmpeg en arrière-plan pour éviter le délai au premier trim.
  Future<void> preWarm() async {
    try {
      await _execute(['-version']);
    } catch (_) {}
  }

  Future<Directory> _exportsDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'exports'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  String _secs(Duration d) => (d.inMilliseconds / 1000.0).toStringAsFixed(3);

  Future<String?> trim({
    required String inputPath,
    required Duration start,
    required Duration end,
    String? outputName,
  }) async {
    final dir = await _exportsDir();
    final ext = p.extension(inputPath);
    final name = outputName ?? p.basenameWithoutExtension(inputPath);
    final ts = DateTime.now().millisecondsSinceEpoch;
    final outPath = p.join(dir.path, '${name}_trim_$ts$ext');

    final success = await _execute([
      '-i', inputPath,
      '-ss', _secs(start),
      '-to', _secs(end),
      '-c', 'copy',
      '-y', outPath,
    ]);
    return success ? outPath : null;
  }

  Future<List<String>> split({
    required String inputPath,
    required List<Duration> timestamps,
    required Duration totalDuration,
  }) async {
    final dir = await _exportsDir();
    final ext = p.extension(inputPath);
    final baseName = p.basenameWithoutExtension(inputPath);
    final ts = DateTime.now().millisecondsSinceEpoch;

    final starts = [Duration.zero, ...timestamps];
    final ends = [...timestamps, totalDuration];

    final paths = <String>[];
    for (int i = 0; i < starts.length; i++) {
      final outPath = p.join(dir.path, '${baseName}_part${i + 1}_$ts$ext');
      final success = await _execute([
        '-i', inputPath,
        '-ss', _secs(starts[i]),
        '-to', _secs(ends[i]),
        '-c', 'copy',
        '-y', outPath,
      ]);
      if (success) paths.add(outPath);
    }
    return paths;
  }

  Future<String?> convertToMp3(String inputPath) async {
    final dir = await _exportsDir();
    final name = p.basenameWithoutExtension(inputPath);
    final ts = DateTime.now().millisecondsSinceEpoch;
    final outPath = p.join(dir.path, '${name}_$ts.mp3');

    final success = await _execute([
      '-i', inputPath,
      '-acodec', 'libmp3lame',
      '-q:a', '2',
      '-y', outPath,
    ]);
    return success ? outPath : null;
  }
}
