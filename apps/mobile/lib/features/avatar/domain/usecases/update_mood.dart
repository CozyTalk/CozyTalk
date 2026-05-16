import '../repositories/avatar_repository.dart';

class UpdateMood {
  final AvatarRepository _repository;
  const UpdateMood(this._repository);

  Future<void> call(String uid, String? moodKey) =>
      _repository.updateMood(uid, moodKey);
}
