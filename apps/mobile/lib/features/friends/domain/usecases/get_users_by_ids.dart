import '../entities/app_user.dart';
import '../repositories/friends_repository.dart';

class GetUsersByIds {
  final FriendsRepository _repository;
  const GetUsersByIds(this._repository);

  Future<List<AppUser>> call(List<String> uids) {
    if (uids.isEmpty) return Future.value([]);
    return _repository.getUsersByIds(uids);
  }
}
