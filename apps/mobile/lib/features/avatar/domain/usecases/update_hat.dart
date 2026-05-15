import '../repositories/avatar_repository.dart';

class UpdateHat {
  final AvatarRepository _repository;
  const UpdateHat(this._repository);

  Future<void> call(String uid, String? hatKey) =>
      _repository.updateHat(uid, hatKey);
}
