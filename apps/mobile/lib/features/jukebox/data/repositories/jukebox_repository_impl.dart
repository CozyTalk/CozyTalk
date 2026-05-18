import '../../domain/entities/jukebox_room_state.dart';
import '../../domain/entities/jukebox_track.dart';
import '../../domain/repositories/jukebox_repository.dart';
import '../datasources/jukebox_datasource.dart';
import '../models/jukebox_room_state_model.dart';
import '../models/jukebox_track_model.dart';

class JukeboxRepositoryImpl implements JukeboxRepository {
  final JukeboxDatasource _datasource;
  JukeboxRepositoryImpl(this._datasource);

  @override
  Stream<JukeboxRoomState?> watchJukebox(String roomId) =>
      _datasource.watchJukebox(roomId).map((m) => m?.toEntity());

  @override
  Future<JukeboxTrack> resolveTrack({
    required String audiomackUrl,
    required String addedBy,
    required String addedByName,
  }) async {
    final uri = Uri.parse(audiomackUrl);
    final segments = uri.pathSegments;
    if (uri.host != 'audiomack.com' ||
        segments.length < 3 ||
        segments[1] != 'song') {
      throw Exception(
        'Invalid Audiomack URL. Expected: audiomack.com/{artist}/song/{slug}',
      );
    }
    final model = await _datasource.fetchTrackMetadata(
      artist: segments[0],
      slug: segments[2],
      addedBy: addedBy,
      addedByName: addedByName,
    );
    return model.toEntity();
  }

  @override
  Future<String> refreshStreamingUrl(String trackId) =>
      _datasource.fetchFreshStreamingUrl(trackId);

  @override
  Future<void> writeJukeboxState({
    required String roomId,
    required JukeboxRoomState roomState,
  }) {
    final model = JukeboxRoomStateModel(
      isPlaying: roomState.isPlaying,
      currentIndex: roomState.currentIndex,
      startedAt: roomState.startedAt,
      queue: roomState.queue
          .map(
            (t) => JukeboxTrackModel(
              id: t.id,
              audiomackUrl: t.audiomackUrl,
              embedUrl: t.embedUrl,
              streamingUrl: t.streamingUrl,
              streamingUrlTimeout: t.streamingUrlTimeout,
              title: t.title,
              artist: t.artist,
              artworkUrl: t.artworkUrl,
              addedBy: t.addedBy,
              addedByName: t.addedByName,
            ),
          )
          .toList(),
    );
    return _datasource.writeState(roomId: roomId, state: model.toJson());
  }

  @override
  Future<void> clearJukebox(String roomId) => _datasource.clearState(roomId);
}
