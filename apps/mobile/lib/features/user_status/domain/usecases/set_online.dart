import '../repositories/user_status_repository.dart';

class SetOnline {
  final UserStatusRepository _repository;

  SetOnline(this._repository);

  Future<void> call() => _repository.setOnline();
}
