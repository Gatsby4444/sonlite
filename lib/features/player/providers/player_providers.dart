import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/services/audio_handler.dart';
export '../../../core/services/audio_handler.dart' show AudioLoopMode;
import '../../../core/database/app_database.dart';

part 'player_providers.g.dart';

// Initialisé dans main.dart, stocké ici comme provider
final audioHandlerProvider = Provider<SonLiteAudioHandler>((ref) {
  throw UnimplementedError('AudioHandler must be initialized in main()');
});

@riverpod
Stream<PlaybackState> playbackState(Ref ref) {
  return ref.watch(audioHandlerProvider).playbackState;
}

@riverpod
Stream<MediaItem?> currentMediaItem(Ref ref) {
  return ref.watch(audioHandlerProvider).mediaItem;
}

@riverpod
Stream<List<MediaItem>> audioQueue(Ref ref) {
  return ref.watch(audioHandlerProvider).queue;
}

// Stream de position mis à jour en continu par just_audio (~200ms)
@riverpod
Stream<Duration> audioPosition(Ref ref) {
  return ref.watch(audioHandlerProvider).player.positionStream;
}

@Riverpod(keepAlive: true)
Stream<AudioLoopMode> loopMode(Ref ref) {
  return ref.watch(audioHandlerProvider).loopModeStream;
}

@Riverpod(keepAlive: true)
Stream<bool> shuffleEnabled(Ref ref) {
  return ref.watch(audioHandlerProvider).shuffleStream;
}

// 0=off, 1=×1, 2=×2, -1=infini
@Riverpod(keepAlive: true)
Stream<int> loopState(Ref ref) {
  return ref.watch(audioHandlerProvider).loopStateStream;
}

// Convertit un Track DB en MediaItem audio_service
MediaItem trackToMediaItem(Track track) {
  return MediaItem(
    id: track.filePath,
    title: track.title,
    artist: track.artist,
    album: track.album,
    duration: Duration(milliseconds: track.durationMs),
    artUri: track.thumbnailPath != null
        ? Uri.file(track.thumbnailPath!)
        : null,
    extras: {'filePath': track.filePath, 'trackId': track.id},
  );
}
