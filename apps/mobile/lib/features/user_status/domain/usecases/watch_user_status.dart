import '../entities/user_status.dart';
import '../repositories/user_status_repository.dart';

class WatchUserStatus {
  final UserStatusRepository _repository;

  WatchUserStatus(this._repository);

  Stream<UserStatus> call(String uid) => _repository.watchStatus(uid);
}
