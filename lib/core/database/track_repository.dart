import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'app_database.dart';
import 'tracks_dao.dart';

part 'track_repository.g.dart';

@Riverpod(keepAlive: true)
TracksDao tracksDao(Ref ref) {
  return ref.watch(appDatabaseProvider).tracksDao;
}

@riverpod
class TrackRepository extends _$TrackRepository {
  @override
  Stream<List<Track>> build() {
    return ref.watch(tracksDaoProvider).watchAllTracks();
  }

  Future<int> addTrack(TracksCompanion track) {
    return ref.read(tracksDaoProvider).insertTrack(track);
  }

  Future<void> deleteTrack(int id) {
    return ref.read(tracksDaoProvider).deleteTrack(id);
  }

  Future<Track?> getTrackById(int id) {
    return ref.read(tracksDaoProvider).getTrackById(id);
  }

  Future<void> updateThumbnail(int id, String? thumbnailPath) {
    return ref.read(tracksDaoProvider).updateThumbnail(id, thumbnailPath);
  }

  Future<void> restoreOriginalThumbnail(int id, String? originalPath) {
    return ref.read(tracksDaoProvider).restoreOriginalThumbnail(id, originalPath);
  }

  Future<List<Track>> searchTracks(String query) {
    return ref.read(tracksDaoProvider).searchTracks(query);
  }
}
