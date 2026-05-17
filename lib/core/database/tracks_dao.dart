import 'package:drift/drift.dart';
import 'app_database.dart';

part 'tracks_dao.g.dart';

@DriftAccessor(tables: [Tracks])
class TracksDao extends DatabaseAccessor<AppDatabase> with _$TracksDaoMixin {
  TracksDao(super.db);

  Future<List<Track>> getAllTracks() =>
      (select(tracks)..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).get();

  Stream<List<Track>> watchAllTracks() =>
      (select(tracks)..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).watch();

  Future<Track?> getTrackById(int id) =>
      (select(tracks)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> insertTrack(TracksCompanion track) =>
      into(tracks).insert(track);

  Future<bool> updateTrack(TracksCompanion track) =>
      update(tracks).replace(track);

  Future<int> updateThumbnail(int id, String? path) =>
      (update(tracks)..where((t) => t.id.equals(id)))
          .write(TracksCompanion(thumbnailPath: Value(path)));

  Future<int> restoreOriginalThumbnail(int id, String? originalPath) =>
      (update(tracks)..where((t) => t.id.equals(id)))
          .write(TracksCompanion(thumbnailPath: Value(originalPath)));

  Future<int> deleteTrack(int id) =>
      (delete(tracks)..where((t) => t.id.equals(id))).go();

  Future<List<Track>> searchTracks(String query) =>
      (select(tracks)
        ..where((t) => t.title.like('%$query%') | t.artist.like('%$query%')))
          .get();
}
