import '../entities/jukebox_room_state.dart';
import '../repositories/jukebox_repository.dart';

class SetPlaying {
  final JukeboxRepository _repository;
  const SetPlaying(this._repository);

  Future<void> call({
    required String roomId,
    required JukeboxRoomState current,
    required bool isPlaying,
    required int pausedAt,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final updated = JukeboxRoomState(
      isPlaying: isPlaying,
      currentIndex: current.currentIndex,
      // When resuming: shift startedAt so seekSeconds = now - startedAt = pausedAt/1000.
      // When pausing: keep startedAt unchanged.
      startedAt: isPlaying ? (now - current.pausedAt) : current.startedAt,
      pausedAt: isPlaying ? 0 : pausedAt,
      queue: current.queue,
    );
    return _repository.writeJukeboxState(roomId: roomId, roomState: updated);
  }
}
