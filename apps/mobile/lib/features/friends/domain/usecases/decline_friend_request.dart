import '../repositories/friends_repository.dart';

class DeclineFriendRequest {
  final FriendsRepository _repository;
  const DeclineFriendRequest(this._repository);

  Future<void> call({required String requestId}) =>
      _repository.declineFriendRequest(requestId: requestId);
}
