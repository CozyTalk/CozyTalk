import '../repositories/friends_repository.dart';

class SendFriendRequest {
  final FriendsRepository _repository;
  const SendFriendRequest(this._repository);

  Future<void> call({
    required String toUid,
    required String toDisplayName,
    required String fromDisplayName,
  }) => _repository.sendFriendRequest(
    toUid: toUid,
    toDisplayName: toDisplayName,
    fromDisplayName: fromDisplayName,
  );
}
