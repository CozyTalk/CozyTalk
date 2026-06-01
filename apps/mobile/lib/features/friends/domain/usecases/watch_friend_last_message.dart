import '../repositories/friends_repository.dart';

class WatchFriendLastMessage {
  final FriendsRepository _repository;
  const WatchFriendLastMessage(this._repository);

  Stream<({String text, DateTime? timestamp})> call(String chatRoomId) =>
      _repository.watchFriendLastMessage(chatRoomId);
}
