import '../entities/room.dart';
import '../repositories/matchmaking_repository.dart';

class JoinRoomById {
  final MatchmakingRepository _repository;
  const JoinRoomById(this._repository);

  Future<({String roomId, RoomMode mode, RoomType roomType})> call(
    String roomId,
  ) => _repository.joinRoomById(roomId);
}
