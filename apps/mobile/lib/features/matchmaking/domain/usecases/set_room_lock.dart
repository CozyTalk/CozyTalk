import '../repositories/matchmaking_repository.dart';

class SetRoomLock {
  final MatchmakingRepository _repository;
  const SetRoomLock(this._repository);

  Future<void> call({required String roomId, required bool isLocked}) =>
      _repository.setRoomLock(roomId: roomId, isLocked: isLocked);
}
