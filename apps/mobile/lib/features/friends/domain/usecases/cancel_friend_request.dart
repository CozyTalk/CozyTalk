import '../repositories/friends_repository.dart';

class CancelFriendRequest {
  final FriendsRepository _repository;
  const CancelFriendRequest(this._repository);

  Future<void> call({required String toUid}) =>
      _repository.cancelFriendRequest(toUid: toUid);
}
