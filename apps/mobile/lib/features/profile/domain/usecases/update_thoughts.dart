import '../repositories/profile_repository.dart';

class UpdateThoughts {
  final ProfileRepository _repository;

  const UpdateThoughts(this._repository);

  Future<void> call(String uid, String thoughts) =>
      _repository.updateThoughts(uid, thoughts);
}
