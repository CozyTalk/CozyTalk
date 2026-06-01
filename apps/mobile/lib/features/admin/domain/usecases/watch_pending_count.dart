import '../repositories/admin_repository.dart';

class WatchPendingCount {
  final AdminRepository _repository;
  WatchPendingCount(this._repository);
  Stream<int> call() => _repository.watchPendingCount();
}
