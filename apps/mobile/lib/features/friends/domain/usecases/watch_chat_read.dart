import '../repositories/friends_repository.dart';

class WatchChatRead {
  final FriendsRepository _repository;
  const WatchChatRead(this._repository);

  Stream<DateTime?> call(String chatRoomId) =>
      _repository.watchChatRead(chatRoomId);
}
