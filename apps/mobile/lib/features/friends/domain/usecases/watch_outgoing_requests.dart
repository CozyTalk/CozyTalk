import '../entities/friend_request.dart';
import '../repositories/friends_repository.dart';

class WatchOutgoingRequests {
  final FriendsRepository _repository;
  const WatchOutgoingRequests(this._repository);

  Stream<List<FriendRequest>> call() => _repository.watchOutgoingRequests();
}
