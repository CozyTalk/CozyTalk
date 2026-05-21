import '../entities/avatar_decoration.dart';
import '../repositories/avatar_repository.dart';

class GetCachedDecoration {
  final AvatarRepository _repository;

  const GetCachedDecoration(this._repository);

  Future<AvatarDecoration?> call(String uid) =>
      _repository.getCachedDecoration(uid);
}
