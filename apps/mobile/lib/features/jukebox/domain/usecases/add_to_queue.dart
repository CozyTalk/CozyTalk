import '../entities/jukebox_room_state.dart';
import '../entities/jukebox_track.dart';
import '../repositories/jukebox_repository.dart';

class AddToQueue {
  final JukeboxRepository _repository;
  const AddToQueue(this._repository);

  Future<JukeboxRoomState> call({
    required String roomId,
    required JukeboxRoomState current,
    required JukeboxTrack track,
  }) async {
    if (current.queue.length >= 4) {
      throw Exception('Queue is full (max 4 tracks).');
    }
    final updated = JukeboxRoomState(
      isPlaying: current.queue.isEmpty ? true : current.isPlaying,
      currentIndex: current.currentIndex,
      startedAt: current.queue.isEmpty
          ? DateTime.now().millisecondsSinceEpoch
          : current.startedAt,
      pausedAt: current.queue.isEmpty ? 0 : current.pausedAt,
      queue: [...current.queue, track],
    );
    await _repository.writeJukeboxState(roomId: roomId, roomState: updated);
    return updated;
  }
}
