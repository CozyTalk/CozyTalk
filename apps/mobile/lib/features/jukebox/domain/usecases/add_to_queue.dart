import '../entities/jukebox_room_state.dart';
import '../entities/jukebox_track.dart';
import '../repositories/jukebox_repository.dart';

class AddToQueue {
  final JukeboxRepository _repository;
  const AddToQueue(this._repository);

  Future<void> call({
    required String roomId,
    required JukeboxRoomState current,
    required JukeboxTrack track,
  }) {
    if (current.queue.length >= 4) {
      throw Exception('Queue is full (max 4 tracks).');
    }
    final updated = JukeboxRoomState(
      isPlaying: current.queue.isEmpty ? true : current.isPlaying,
      currentIndex: current.currentIndex,
      startedAt: current.queue.isEmpty
          ? DateTime.now().millisecondsSinceEpoch
          : current.startedAt,
      queue: [...current.queue, track],
    );
    return _repository.writeJukeboxState(roomId: roomId, roomState: updated);
  }
}
