import '../repositories/friends_repository.dart';

class GetUnreadMessageCount {
  final FriendsRepository _repository;
  const GetUnreadMessageCount(this._repository);

  Future<int> call(
    String chatRoomId, {
    required int sinceMs,
    required String friendUid,
  }) => _repository.getUnreadMessageCount(
    chatRoomId,
    sinceMs: sinceMs,
    friendUid: friendUid,
  );
}
