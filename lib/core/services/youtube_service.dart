import 'dart:async';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../database/app_database.dart';
import '../database/track_repository.dart';

part 'youtube_service.g.dart';

enum DownloadStatus { idle, fetching, downloading, processing, done, error }

class DownloadProgress {
  final String? title;
  final DownloadStatus status;
  final double progress; // 0.0 à 1.0
  final String? error;

  const DownloadProgress({
    this.title,
    required this.status,
    this.progress = 0,
    this.error,
  });

  static const idle = DownloadProgress(status: DownloadStatus.idle);
}

@riverpod
YoutubeService youtubeService(Ref ref) => YoutubeService(ref);

class YoutubeService {
  final Ref _ref;

  YoutubeService(this._ref);

  /// Pont vers la bibliothèque youtubedl-android (côté Kotlin).
  static const _channel = MethodChannel('com.sonlite/ytdlp');
  static const _progressChannel = EventChannel('com.sonlite/ytdlp_progress');

  static bool _updateAttempted = false;

  /// Met à jour yt-dlp vers la dernière version (1x par lancement de l'app).
  /// Sans ça, YouTube finit par renvoyer des erreurs 403 sur les vieilles versions.
  /// Échec non bloquant : on tente quand même le téléchargement.
  Future<void> _ensureUpdated() async {
    if (_updateAttempted) return;
    _updateAttempted = true;
    try {
      final status = await _channel.invokeMethod<String>('update');
      debugPrint('[yt-dlp] mise à jour: $status');
    } catch (e) {
      debugPrint('[yt-dlp] mise à jour échouée (non bloquant): $e');
    }
  }

  Future<Track?> downloadAudio(
    String url,
    void Function(DownloadProgress) onProgress,
  ) async {
    onProgress(const DownloadProgress(status: DownloadStatus.fetching));
    StreamSubscription<dynamic>? progressSub;

    try {
      // yt-dlp doit être à jour, sinon YouTube renvoie des 403.
      debugPrint('[download] 1/7 mise à jour yt-dlp');
      await _ensureUpdated();

      debugPrint('[download] 2/7 dossier musique');
      final musicDir = await _getMusicDir();

      // 1. Métadonnées (le premier appel initialise le runtime Python — lent)
      onProgress(const DownloadProgress(
        status: DownloadStatus.fetching,
        progress: 0.05,
      ));

      debugPrint('[download] 3/7 getInfo');
      final info = await _channel
          .invokeMapMethod<String, dynamic>('getInfo', {'url': url});
      if (info == null) {
        throw Exception('Impossible de récupérer les infos de la vidéo');
      }

      final title = (info['title'] as String?)?.trim() ?? 'Titre inconnu';
      final durationSec = (info['duration'] as num?)?.toInt() ?? 0;
      final thumbnailUrl = info['thumbnail'] as String?;
      final uploader = (info['uploader'] as String?)?.trim() ?? 'Artiste inconnu';
      final videoId = info['id'] as String?;

      onProgress(DownloadProgress(
        title: title,
        status: DownloadStatus.downloading,
        progress: 0.1,
      ));

      final safeTitle = _sanitizeFilename(title);
      final outputTemplate = p.join(musicDir.path, '$safeTitle.%(ext)s');

      // 2. Écoute de la progression — capture aussi le chemin du fichier final
      String? capturedPath;
      progressSub = _progressChannel.receiveBroadcastStream().listen((event) {
        if (event is! Map) return;

        final line = event['line'] as String? ?? '';
        final destMatch =
            RegExp(r'\[(?:ExtractAudio|download)\] Destination: (.+)')
                .firstMatch(line);
        if (destMatch != null) {
          // [ExtractAudio] arrive après [download] — le dernier gagne
          capturedPath = destMatch.group(1)!.trim();
        }

        final pct = (event['progress'] as num?)?.toDouble() ?? -1;
        if (pct >= 0) {
          onProgress(DownloadProgress(
            title: title,
            status: DownloadStatus.downloading,
            progress: 0.1 + 0.8 * (pct / 100).clamp(0.0, 1.0),
          ));
        }
      });

      // 3. Téléchargement (bloque jusqu'à la fin)
      debugPrint('[download] 4/7 invokeMethod download...');
      await _channel.invokeMethod('download', {
        'url': url,
        'outputTemplate': outputTemplate,
      });
      debugPrint('[download] 4/7 invokeMethod download OK');

      await progressSub.cancel();
      progressSub = null;
      debugPrint('[download] 5/7 progressSub annulé');

      onProgress(DownloadProgress(
        title: title,
        status: DownloadStatus.processing,
        progress: 0.95,
      ));

      // 4. Déterminer le fichier audio produit
      String? finalFilePath;
      if (capturedPath != null && File(capturedPath!).existsSync()) {
        finalFilePath = capturedPath;
      } else {
        // Repli : scan du dossier, restreint aux extensions audio
        const audioExts = {
          '.opus', '.m4a', '.mp3', '.aac', '.flac', '.ogg', '.wav'
        };
        final files = musicDir
            .listSync()
            .whereType<File>()
            .where((f) =>
                p.basenameWithoutExtension(f.path) == safeTitle &&
                audioExts.contains(p.extension(f.path).toLowerCase()))
            .toList();
        if (files.isNotEmpty) {
          files.sort(
              (a, b) => b.statSync().modified.compareTo(a.statSync().modified));
          finalFilePath = files.first.path;
        }
      }
      if (finalFilePath == null || !File(finalFilePath).existsSync()) {
        throw Exception('Fichier audio introuvable après téléchargement');
      }
      debugPrint('[download] 6/7 fichier trouvé: $finalFilePath');

      // 5. Miniature pour l'UI (séparée de celle embarquée dans le fichier)
      String? thumbnailPath;
      if (thumbnailUrl != null && thumbnailUrl.startsWith('http')) {
        try {
          thumbnailPath = await _downloadThumbnail(thumbnailUrl, safeTitle, musicDir);
        } catch (e) {
          debugPrint('[download] thumbnail failed: $e');
        }
      }

      // 6. Enregistrement en base
      debugPrint('[download] 7/7 insertion en base');
      final id = await _ref.read(tracksDaoProvider).insertTrack(
            TracksCompanion.insert(
              title: title,
              artist: Value(uploader),
              durationMs: Value(durationSec * 1000),
              filePath: finalFilePath,
              thumbnailPath: Value(thumbnailPath),
              originalThumbnailPath: Value(thumbnailPath),
              youtubeUrl: Value(url),
              youtubeId: Value(videoId),
              source: const Value('youtube'),
            ),
          );

      onProgress(DownloadProgress(
        title: title,
        status: DownloadStatus.done,
        progress: 1.0,
      ));

      return _ref.read(tracksDaoProvider).getTrackById(id);
    } catch (e, st) {
      debugPrint('[download] ERREUR: $e');
      debugPrint('[download] STACK:\n$st');
      onProgress(DownloadProgress(
        status: DownloadStatus.error,
        error: e.toString(),
      ));
      return null;
    } finally {
      await progressSub?.cancel();
    }
  }

  Future<String?> _downloadThumbnail(
    String url,
    String baseName,
    Directory dir,
  ) async {
    final client = HttpClient();
    final request = await client.getUrl(Uri.parse(url));
    final response = await request.close();
    final thumbPath = p.join(dir.path, '${baseName}_thumb.jpg');
    final sink = File(thumbPath).openWrite();
    await response.pipe(sink);
    client.close();
    return thumbPath;
  }

  Future<Directory> _getMusicDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'music'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  String _sanitizeFilename(String name) {
    return name
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .substring(0, name.length.clamp(0, 100));
  }
}
