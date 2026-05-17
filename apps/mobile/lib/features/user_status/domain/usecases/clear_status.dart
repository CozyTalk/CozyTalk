import '../repositories/user_status_repository.dart';

class ClearStatus {
  final UserStatusRepository _repository;

  ClearStatus(this._repository);

  Future<void> call() => _repository.clearStatus();
}
