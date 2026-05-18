import '../entities/jukebox_room_state.dart';
import '../repositories/jukebox_repository.dart';

class SkipTrack {
  final JukeboxRepository _repository;
  const SkipTrack(this._repository);

  Future<void> call({
    required String roomId,
    required JukeboxRoomState current,
  }) {
    final next = current.currentIndex + 1;
    if (next >= current.queue.length) return _repository.clearJukebox(roomId);
    final updated = JukeboxRoomState(
      isPlaying: true,
      currentIndex: next,
      startedAt: DateTime.now().millisecondsSinceEpoch,
      queue: current.queue,
    );
    return _repository.writeJukeboxState(roomId: roomId, roomState: updated);
  }
}
