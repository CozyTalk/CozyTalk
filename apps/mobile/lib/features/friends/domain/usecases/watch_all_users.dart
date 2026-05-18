import '../entities/app_user.dart';
import '../repositories/friends_repository.dart';

class WatchAllUsers {
  final FriendsRepository _repository;
  const WatchAllUsers(this._repository);

  Stream<List<AppUser>> call() => _repository.watchAllUsers();
}
