import '../entities/avatar_decoration.dart';
import '../repositories/avatar_repository.dart';

class GetAvatarDecoration {
  final AvatarRepository _repository;
  const GetAvatarDecoration(this._repository);

  Future<AvatarDecoration?> call(String uid) => _repository.getDecoration(uid);
}
