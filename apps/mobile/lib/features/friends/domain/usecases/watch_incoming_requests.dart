import '../entities/friend_request.dart';
import '../repositories/friends_repository.dart';

class WatchIncomingRequests {
  final FriendsRepository _repository;
  const WatchIncomingRequests(this._repository);

  Stream<List<FriendRequest>> call() => _repository.watchIncomingRequests();
}
