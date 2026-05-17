import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:drift/drift.dart';

import 'app_database.dart';
import 'playlists_dao.dart';

part 'playlist_repository.g.dart';

@Riverpod(keepAlive: true)
PlaylistsDao playlistsDao(Ref ref) {
  return ref.watch(appDatabaseProvider).playlistsDao;
}

@riverpod
class PlaylistRepository extends _$PlaylistRepository {
  @override
  Stream<List<Playlist>> build() {
    return ref.watch(playlistsDaoProvider).watchAllPlaylists();
  }

  Future<int> createPlaylist(String name, {String? thumbnailPath}) {
    return ref.read(playlistsDaoProvider).insertPlaylist(
          PlaylistsCompanion.insert(
            name: name,
            thumbnailPath: Value(thumbnailPath),
          ),
        );
  }

  Future<void> deletePlaylist(int id) {
    return ref.read(playlistsDaoProvider).deletePlaylist(id);
  }

  Future<void> addTrack(int playlistId, int trackId) {
    return ref.read(playlistsDaoProvider).addTrackToPlaylist(playlistId, trackId);
  }

  Future<void> removeTrack(int playlistId, int trackId) {
    return ref.read(playlistsDaoProvider).removeTrackFromPlaylist(playlistId, trackId);
  }

  Future<List<Track>> getTracksForPlaylist(int playlistId) {
    return ref.read(playlistsDaoProvider).getTracksForPlaylist(playlistId);
  }

  Future<void> updatePlaylist(int id, String name, {String? thumbnailPath}) {
    return ref.read(playlistsDaoProvider).updatePlaylist(
          PlaylistsCompanion(
            id: Value(id),
            name: Value(name),
            thumbnailPath: Value(thumbnailPath),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }

  Future<void> reorderTracks(int playlistId, List<int> orderedTrackIds) {
    return ref.read(playlistsDaoProvider).reorderTracks(playlistId, orderedTrackIds);
  }
}
