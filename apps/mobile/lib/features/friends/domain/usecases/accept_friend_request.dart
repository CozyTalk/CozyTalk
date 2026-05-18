import '../repositories/friends_repository.dart';

class AcceptFriendRequest {
  final FriendsRepository _repository;
  const AcceptFriendRequest(this._repository);

  Future<void> call({
    required String requestId,
    required String fromUid,
    required String fromDisplayName,
    required String myDisplayName,
  }) => _repository.acceptFriendRequest(
    requestId: requestId,
    fromUid: fromUid,
    fromDisplayName: fromDisplayName,
    myDisplayName: myDisplayName,
  );
}
