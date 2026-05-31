import '../repositories/friends_repository.dart';

class SetFriendTyping {
  final FriendsRepository _repository;
  const SetFriendTyping(this._repository);

  Future<void> call(String chatRoomId, bool isTyping) =>
      _repository.setFriendTyping(chatRoomId, isTyping);
}
