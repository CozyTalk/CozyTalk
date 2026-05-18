import '../entities/jukebox_room_state.dart';
import '../repositories/jukebox_repository.dart';

class SetPlaying {
  final JukeboxRepository _repository;
  const SetPlaying(this._repository);

  Future<void> call({
    required String roomId,
    required JukeboxRoomState current,
    required bool isPlaying,
  }) {
    final updated = JukeboxRoomState(
      isPlaying: isPlaying,
      currentIndex: current.currentIndex,
      startedAt: (isPlaying && !current.isPlaying)
          ? DateTime.now().millisecondsSinceEpoch
          : current.startedAt,
      queue: current.queue,
    );
    return _repository.writeJukeboxState(roomId: roomId, roomState: updated);
  }
}
