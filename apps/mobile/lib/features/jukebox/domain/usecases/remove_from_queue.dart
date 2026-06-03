import '../entities/jukebox_room_state.dart';
import '../entities/jukebox_track.dart';
import '../repositories/jukebox_repository.dart';

class RemoveFromQueue {
  final JukeboxRepository _repository;
  const RemoveFromQueue(this._repository);

  Future<JukeboxRoomState?> call({
    required String roomId,
    required JukeboxRoomState current,
    required int index,
  }) async {
    if (index < 0 || index >= current.queue.length) return null;
    final newQueue = List<JukeboxTrack>.from(current.queue)..removeAt(index);
    if (newQueue.isEmpty) {
      await _repository.clearJukebox(roomId);
      return null;
    }
    int newIndex = current.currentIndex;
    if (index < current.currentIndex) newIndex--;
    newIndex = newIndex.clamp(0, newQueue.length - 1);
    final updated = JukeboxRoomState(
      isPlaying: current.isPlaying,
      currentIndex: newIndex,
      startedAt: index == current.currentIndex
          ? DateTime.now().millisecondsSinceEpoch
          : current.startedAt,
      queue: newQueue,
    );
    await _repository.writeJukeboxState(roomId: roomId, roomState: updated);
    return updated;
  }
}
