import '../repositories/user_status_repository.dart';

class WatchOnlineCount {
  final UserStatusRepository _repository;

  WatchOnlineCount(this._repository);

  Stream<int> call() => _repository.watchOnlineCount();
}
