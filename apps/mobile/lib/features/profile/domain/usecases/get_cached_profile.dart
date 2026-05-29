import '../entities/profile_user.dart';
import '../repositories/profile_repository.dart';

class GetCachedProfile {
  final ProfileRepository _repository;

  const GetCachedProfile(this._repository);

  Future<ProfileUser?> call(String uid) => _repository.getCachedProfile(uid);
}
