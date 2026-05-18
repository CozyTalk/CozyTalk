import '../entities/friend_message.dart';
import '../repositories/friends_repository.dart';

class WatchFriendMessages {
  final FriendsRepository _repository;
  const WatchFriendMessages(this._repository);

  Stream<List<FriendMessage>> call(String chatRoomId) =>
      _repository.watchMessages(chatRoomId);
}
