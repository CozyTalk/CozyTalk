import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/friends/domain/usecases/remove_friend.dart';

import '../shared_fakes.dart';

void main() {
  late FakeFriendsRepository repo;
  late RemoveFriend usecase;

  setUp(() {
    repo = FakeFriendsRepository();
    usecase = RemoveFriend(repo);
  });

  test('forwards friendshipId to repository', () async {
    await usecase(friendshipId: 'uid-1_uid-2');
    expect(repo.removeFriendCount, 1);
    expect(repo.lastRemovedFriendshipId, 'uid-1_uid-2');
  });

  test('propagates repository exception', () {
    repo.error = Exception('friendship not found');
    expect(
      () => usecase(friendshipId: 'uid-1_uid-2'),
      throwsA(isA<Exception>()),
    );
  });
}
