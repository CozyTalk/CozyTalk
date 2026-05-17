import '../entities/profile_user.dart';
import '../repositories/profile_repository.dart';

class GetProfile {
  final ProfileRepository _repository;

  const GetProfile(this._repository);

  Future<ProfileUser> call(String uid) => _repository.getProfile(uid);
}
