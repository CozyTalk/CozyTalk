import '../entities/jukebox_room_state.dart';
import '../repositories/jukebox_repository.dart';

class WatchJukebox {
  final JukeboxRepository _repository;
  const WatchJukebox(this._repository);

  Stream<JukeboxRoomState?> call(String roomId) =>
      _repository.watchJukebox(roomId);
}
