import 'package:drift/drift.dart';
import 'app_database.dart';

part 'playlists_dao.g.dart';

class PlaylistWithTracks {
  final Playlist playlist;
  final List<Track> tracks;
  PlaylistWithTracks({required this.playlist, required this.tracks});
}

class PlaylistTrackEntry {
  final Track track;
  final bool isEnabled;
  final int position;
  PlaylistTrackEntry({
    required this.track,
    required this.isEnabled,
    required this.position,
  });
}

@DriftAccessor(tables: [Playlists, PlaylistTracks, Tracks])
class PlaylistsDao extends DatabaseAccessor<AppDatabase>
    with _$PlaylistsDaoMixin {
  PlaylistsDao(super.db);

  Stream<List<Playlist>> watchAllPlaylists() =>
      (select(playlists)..orderBy([(p) => OrderingTerm.desc(p.updatedAt)])).watch();

  Future<List<Playlist>> getAllPlaylists() =>
      (select(playlists)..orderBy([(p) => OrderingTerm.desc(p.updatedAt)])).get();

  Future<int> insertPlaylist(PlaylistsCompanion playlist) =>
      into(playlists).insert(playlist);

  Future<int> updatePlaylist(PlaylistsCompanion companion) =>
      (update(playlists)..where((p) => p.id.equals(companion.id.value)))
          .write(companion);

  Future<int> deletePlaylist(int id) =>
      (delete(playlists)..where((p) => p.id.equals(id))).go();

  // Récupère les pistes d'une playlist avec leur état enabled, triées par position
  Future<List<PlaylistTrackEntry>> getTracksForPlaylist(int playlistId) async {
    final query = select(playlistTracks).join([
      innerJoin(tracks, tracks.id.equalsExp(playlistTracks.trackId)),
    ])
      ..where(playlistTracks.playlistId.equals(playlistId))
      ..orderBy([OrderingTerm.asc(playlistTracks.position)]);

    final rows = await query.get();
    return rows.map((r) => PlaylistTrackEntry(
      track: r.readTable(tracks),
      isEnabled: r.readTable(playlistTracks).isEnabled,
      position: r.readTable(playlistTracks).position,
    )).toList();
  }

  Future<void> setTrackEnabled(int playlistId, int trackId, bool enabled) async {
    await (update(playlistTracks)
      ..where((pt) =>
          pt.playlistId.equals(playlistId) & pt.trackId.equals(trackId)))
        .write(PlaylistTracksCompanion(isEnabled: Value(enabled)));
  }

  Future<void> addTrackToPlaylist(int playlistId, int trackId) async {
    final existing = await (select(playlistTracks)
      ..where((pt) =>
          pt.playlistId.equals(playlistId) & pt.trackId.equals(trackId)))
        .getSingleOrNull();
    if (existing != null) return;

    final count = await (select(playlistTracks)
      ..where((pt) => pt.playlistId.equals(playlistId)))
        .get()
        .then((rows) => rows.length);

    await into(playlistTracks).insert(PlaylistTracksCompanion.insert(
      playlistId: playlistId,
      trackId: trackId,
      position: count,
    ));

    await (update(playlists)..where((p) => p.id.equals(playlistId))).write(
      PlaylistsCompanion(updatedAt: Value(DateTime.now())),
    );
  }

  Future<void> removeTrackFromPlaylist(int playlistId, int trackId) async {
    await (delete(playlistTracks)
      ..where((pt) =>
          pt.playlistId.equals(playlistId) & pt.trackId.equals(trackId)))
        .go();
    await _reorderPositions(playlistId);
  }

  Future<void> reorderTracks(int playlistId, List<int> orderedTrackIds) async {
    await transaction(() async {
      for (var i = 0; i < orderedTrackIds.length; i++) {
        await (update(playlistTracks)
          ..where((pt) =>
              pt.playlistId.equals(playlistId) &
              pt.trackId.equals(orderedTrackIds[i])))
            .write(PlaylistTracksCompanion(position: Value(i)));
      }
    });
  }

  Future<void> _reorderPositions(int playlistId) async {
    final rows = await (select(playlistTracks)
      ..where((pt) => pt.playlistId.equals(playlistId))
      ..orderBy([(pt) => OrderingTerm.asc(pt.position)]))
        .get();

    for (var i = 0; i < rows.length; i++) {
      await (update(playlistTracks)..where((pt) => pt.id.equals(rows[i].id)))
          .write(PlaylistTracksCompanion(position: Value(i)));
    }
  }
}
