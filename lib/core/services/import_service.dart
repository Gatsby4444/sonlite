import 'dart:io';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_media_metadata/flutter_media_metadata.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../database/app_database.dart';
import '../database/track_repository.dart';
import 'log_service.dart';

part 'import_service.g.dart';

@riverpod
ImportService importService(Ref ref) {
  return ImportService(ref);
}

class ImportService {
  final Ref _ref;
  ImportService(this._ref);

  Future<List<Track>> pickAndImportFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'm4a', 'aac', 'flac', 'ogg', 'wav'],
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return [];

    final imported = <Track>[];
    for (final file in result.files) {
      if (file.path == null) continue;
      final track = await _importFile(file.path!);
      if (track != null) imported.add(track);
    }
    return imported;
  }

  Future<Track?> importFromPath(String sourcePath) =>
      _importFile(sourcePath);

  /// Génère un destPath qui n'écrase pas un fichier existant.
  /// foo.mp3 → foo.mp3 ; si présent → foo_1.mp3 ; etc.
  String _uniqueDestPath(String dirPath, String fileName) {
    final stem = p.basenameWithoutExtension(fileName);
    final ext = p.extension(fileName);
    var candidate = p.join(dirPath, fileName);
    var i = 1;
    while (File(candidate).existsSync()) {
      candidate = p.join(dirPath, '${stem}_$i$ext');
      i++;
    }
    return candidate;
  }

  Future<Track?> _importFile(String sourcePath) async {
    final musicDir = await _getMusicDir();
    final fileName = p.basename(sourcePath);
    // Sans ça, deux imports portant le même nom → File.copy écrase + deux
    // entrées Track partagent le même filePath = bug de swipe bloqué.
    final destPath = _uniqueDestPath(musicDir.path, fileName);
    if (destPath != p.join(musicDir.path, fileName)) {
      appLog('collision de nom : $fileName → ${p.basename(destPath)}',
          level: LogLevel.warn, source: 'import');
    }

    await File(sourcePath).copy(destPath);
    appLog('import : ${p.basename(destPath)}', source: 'import');

    // Extraction des métadonnées
    Metadata? meta;
    try {
      meta = await MetadataRetriever.fromFile(File(destPath));
    } catch (e) {
      debugPrint('[import] metadata extraction failed: $e');
    }

    final title = (meta?.trackName?.isNotEmpty == true)
        ? meta!.trackName!
        : p.basenameWithoutExtension(fileName);
    final artist = meta?.trackArtistNames?.join(', ') ?? 'Artiste inconnu';
    final album = meta?.albumName;
    final durationMs = meta?.trackDuration ?? 0;

    // Sauvegarde de la pochette embarquée si présente
    String? thumbnailPath;
    if (meta?.albumArt != null) {
      try {
        final thumbFile = File(
          p.join(musicDir.path, '${p.basenameWithoutExtension(fileName)}_thumb.jpg'),
        );
        await thumbFile.writeAsBytes(meta!.albumArt!);
        thumbnailPath = thumbFile.path;
      } catch (e) {
        debugPrint('[import] thumbnail save failed: $e');
      }
    }

    final id = await _ref.read(tracksDaoProvider).insertTrack(
          TracksCompanion.insert(
            title: title,
            artist: Value(artist),
            album: Value(album),
            durationMs: Value(durationMs),
            filePath: destPath,
            thumbnailPath: Value(thumbnailPath),
            originalThumbnailPath: Value(thumbnailPath),
            source: const Value('import'),
          ),
        );

    return _ref.read(tracksDaoProvider).getTrackById(id);
  }

  Future<Directory> _getMusicDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'music'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }
}
