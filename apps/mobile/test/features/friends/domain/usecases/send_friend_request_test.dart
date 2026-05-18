import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/friends/domain/usecases/send_friend_request.dart';

import '../shared_fakes.dart';

void main() {
  late FakeFriendsRepository repo;
  late SendFriendRequest usecase;

  setUp(() {
    repo = FakeFriendsRepository();
    usecase = SendFriendRequest(repo);
  });

  test('forwards all parameters to repository', () async {
    await usecase(
      toUid: 'uid-2',
      toDisplayName: 'Bob',
      fromDisplayName: 'Alice',
    );
    expect(repo.sendFriendRequestCount, 1);
    expect(repo.lastToUid, 'uid-2');
    expect(repo.lastToDisplayName, 'Bob');
    expect(repo.lastFromDisplayName, 'Alice');
  });

  test('propagates repository exception', () {
    repo.error = Exception('request already exists');
    expect(
      () => usecase(
        toUid: 'uid-2',
        toDisplayName: 'Bob',
        fromDisplayName: 'Alice',
      ),
      throwsA(isA<Exception>()),
    );
  });
}
