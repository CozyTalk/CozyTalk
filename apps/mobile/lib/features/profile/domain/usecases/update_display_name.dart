import '../repositories/profile_repository.dart';

class UpdateDisplayName {
  final ProfileRepository _repository;

  const UpdateDisplayName(this._repository);

  Future<void> call(String uid, String displayName) =>
      _repository.updateDisplayName(uid, displayName);
}
