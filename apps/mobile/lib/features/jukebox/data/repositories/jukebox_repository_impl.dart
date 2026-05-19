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
    required String youtubeUrl,
    required String addedBy,
    required String addedByName,
  }) async {
    final videoId = _extractVideoId(youtubeUrl);
    if (videoId == null || videoId.isEmpty) {
      throw Exception(
        'Invalid YouTube URL. Paste a youtube.com/watch?v=... or youtu.be/... link.',
      );
    }
    final model = await _datasource.fetchTrackMetadata(
      videoId: videoId,
      addedBy: addedBy,
      addedByName: addedByName,
    );
    return model.toEntity();
  }

  @override
  Future<void> writeJukeboxState({
    required String roomId,
    required JukeboxRoomState roomState,
  }) {
    final model = JukeboxRoomStateModel(
      isPlaying: roomState.isPlaying,
      currentIndex: roomState.currentIndex,
      startedAt: roomState.startedAt,
      pausedAt: roomState.pausedAt,
      queue: roomState.queue
          .map(
            (t) => JukeboxTrackModel(
              id: t.id,
              youtubeUrl: t.youtubeUrl,
              videoId: t.videoId,
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

  static String? _extractVideoId(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return null;
    final host = uri.host.replaceFirst('www.', '');
    if (host == 'youtu.be') return uri.pathSegments.firstOrNull;
    if (host == 'youtube.com') {
      if (uri.queryParameters.containsKey('v')) {
        return uri.queryParameters['v'];
      }
      if (uri.pathSegments.length >= 2 &&
          (uri.pathSegments[0] == 'embed' || uri.pathSegments[0] == 'shorts')) {
        return uri.pathSegments[1];
      }
    }
    return null;
  }
}
