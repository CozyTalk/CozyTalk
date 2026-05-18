import '../entities/jukebox_room_state.dart';
import '../entities/jukebox_track.dart';

abstract class JukeboxRepository {
  Stream<JukeboxRoomState?> watchJukebox(String roomId);

  Future<JukeboxTrack> resolveTrack({
    required String audiomackUrl,
    required String addedBy,
    required String addedByName,
  });

  Future<String> refreshStreamingUrl(String trackId);

  Future<void> writeJukeboxState({
    required String roomId,
    required JukeboxRoomState roomState,
  });

  Future<void> clearJukebox(String roomId);
}
