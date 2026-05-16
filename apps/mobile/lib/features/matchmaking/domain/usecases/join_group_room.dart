import '../repositories/matchmaking_repository.dart';

class JoinGroupRoom {
  final MatchmakingRepository _repository;
  const JoinGroupRoom(this._repository);

  Future<({String roomId, bool isNewRoom})> call() =>
      _repository.joinGroupRoom();
}
