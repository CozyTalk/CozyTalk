import '../entities/friend.dart';
import '../repositories/friends_repository.dart';

class WatchFriends {
  final FriendsRepository _repository;
  const WatchFriends(this._repository);

  Stream<List<Friend>> call() => _repository.watchFriends();
}
