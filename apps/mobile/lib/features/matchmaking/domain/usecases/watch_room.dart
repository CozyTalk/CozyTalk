import '../entities/room.dart';
import '../repositories/matchmaking_repository.dart';

class WatchRoom {
  final MatchmakingRepository _repository;
  const WatchRoom(this._repository);

  Stream<Room?> call(String roomId) => _repository.watchRoom(roomId);
}
