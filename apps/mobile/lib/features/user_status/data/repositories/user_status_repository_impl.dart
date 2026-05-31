import '../../domain/entities/user_status.dart';
import '../../domain/repositories/user_status_repository.dart';
import '../datasources/user_status_datasource.dart';
import '../models/user_status_model.dart';

class UserStatusRepositoryImpl implements UserStatusRepository {
  final UserStatusDatasource _datasource;

  UserStatusRepositoryImpl(this._datasource);

  @override
  Stream<UserStatus> watchStatus(String uid) {
    return _datasource
        .watchStatus(uid)
        .map(
          (model) =>
              model?.toEntity(uid) ??
              UserStatus(uid: uid, status: UserOnlineStatus.offline),
        );
  }

  @override
  Stream<int> watchOnlineCount() => _datasource.watchOnlineCount();

  @override
  Future<void> setOnline() => _datasource.setOnline();

  @override
  Future<void> setInRoom({
    required String roomId,
    required String mode,
    required int maxUsers,
    required int memberCount,
    required bool isLocked,
    String? backgroundTheme,
  }) => _datasource.setInRoom(
    roomId: roomId,
    mode: mode,
    maxUsers: maxUsers,
    memberCount: memberCount,
    isLocked: isLocked,
    backgroundTheme: backgroundTheme,
  );

  @override
  Future<void> clearStatus() => _datasource.clearStatus();
}
