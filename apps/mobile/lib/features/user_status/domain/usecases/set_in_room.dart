import '../repositories/user_status_repository.dart';

class SetInRoom {
  final UserStatusRepository _repository;

  SetInRoom(this._repository);

  Future<void> call({
    required String roomId,
    required String mode,
    required int maxUsers,
    required int memberCount,
    required bool isLocked,
    String? backgroundTheme,
  }) => _repository.setInRoom(
    roomId: roomId,
    mode: mode,
    maxUsers: maxUsers,
    memberCount: memberCount,
    isLocked: isLocked,
    backgroundTheme: backgroundTheme,
  );
}
