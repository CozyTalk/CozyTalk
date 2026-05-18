import '../repositories/friends_repository.dart';

class RemoveFriend {
  final FriendsRepository _repository;
  const RemoveFriend(this._repository);

  Future<void> call({required String friendshipId}) =>
      _repository.removeFriend(friendshipId: friendshipId);
}
