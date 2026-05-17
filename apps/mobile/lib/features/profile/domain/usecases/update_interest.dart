import '../repositories/profile_repository.dart';

class UpdateInterest {
  final ProfileRepository _repository;

  const UpdateInterest(this._repository);

  Future<void> call(String uid, String interest) =>
      _repository.updateInterest(uid, interest);
}
