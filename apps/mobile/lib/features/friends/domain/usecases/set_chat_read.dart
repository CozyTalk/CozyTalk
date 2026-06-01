import '../repositories/friends_repository.dart';

class SetChatRead {
  final FriendsRepository _repository;
  const SetChatRead(this._repository);

  Future<void> call(String chatRoomId) => _repository.setChatRead(chatRoomId);
}
