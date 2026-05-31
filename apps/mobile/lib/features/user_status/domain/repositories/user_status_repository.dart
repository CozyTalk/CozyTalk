import '../entities/user_status.dart';

abstract class UserStatusRepository {
  Stream<UserStatus> watchStatus(String uid);
  Future<void> setOnline();
  Future<void> setInRoom({
    required String roomId,
    required String mode,
    required int maxUsers,
    required int memberCount,
    required bool isLocked,
    String? backgroundTheme,
  });
  Future<void> clearStatus();
}
