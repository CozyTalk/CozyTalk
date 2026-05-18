import '../repositories/friends_repository.dart';

class SendFriendMessage {
  final FriendsRepository _repository;
  const SendFriendMessage(this._repository);

  Future<void> call({
    required String chatRoomId,
    required String text,
    required String senderDisplayName,
  }) => _repository.sendMessage(
    chatRoomId: chatRoomId,
    text: text,
    senderDisplayName: senderDisplayName,
  );
}
