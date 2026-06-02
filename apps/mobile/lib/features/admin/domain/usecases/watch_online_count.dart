import '../repositories/admin_repository.dart';

class WatchOnlineCount {
  final AdminRepository _repository;
  WatchOnlineCount(this._repository);
  Stream<int> call() => _repository.watchOnlineCount();
}
