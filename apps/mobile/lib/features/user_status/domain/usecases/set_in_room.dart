import '../repositories/user_status_repository.dart';

class SetInRoom {
  final UserStatusRepository _repository;

  SetInRoom(this._repository);

  Future<void> call({required String roomId, required String mode}) =>
      _repository.setInRoom(roomId: roomId, mode: mode);
}
