import '../repositories/matchmaking_repository.dart';

class LeaveRoom {
  final MatchmakingRepository _repository;
  const LeaveRoom(this._repository);

  Future<void> call(String roomId) => _repository.leaveRoom(roomId);
}
