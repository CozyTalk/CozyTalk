import '../entities/user_status.dart';

abstract class UserStatusRepository {
  Stream<UserStatus> watchStatus(String uid);
  Stream<int> watchOnlineCount();
  Future<void> setOnline();
  Future<void> setInRoom({required String roomId, required String mode});
  Future<void> clearStatus();
}
