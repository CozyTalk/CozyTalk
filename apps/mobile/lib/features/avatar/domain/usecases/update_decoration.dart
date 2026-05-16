import '../repositories/avatar_repository.dart';

class UpdateDecoration {
  final AvatarRepository _repository;
  UpdateDecoration(this._repository);

  Future<void> call(String uid, String? hatKey, String? moodKey) =>
      _repository.updateDecoration(uid, hatKey, moodKey);
}
