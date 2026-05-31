import '../repositories/friends_repository.dart';

class WatchFriendTyping {
  final FriendsRepository _repository;
  const WatchFriendTyping(this._repository);

  Stream<bool> call(String chatRoomId) =>
      _repository.watchFriendTyping(chatRoomId);
}
