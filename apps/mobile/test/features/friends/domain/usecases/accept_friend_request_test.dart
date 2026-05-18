import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/friends/domain/usecases/accept_friend_request.dart';

import '../shared_fakes.dart';

void main() {
  late FakeFriendsRepository repo;
  late AcceptFriendRequest usecase;

  setUp(() {
    repo = FakeFriendsRepository();
    usecase = AcceptFriendRequest(repo);
  });

  test('forwards all parameters to repository', () async {
    await usecase(
      requestId: 'req-1',
      fromUid: 'uid-1',
      fromDisplayName: 'Alice',
      myDisplayName: 'Bob',
    );
    expect(repo.acceptFriendRequestCount, 1);
    expect(repo.lastAcceptedRequestId, 'req-1');
    expect(repo.lastAcceptedFromUid, 'uid-1');
    expect(repo.lastAcceptedFromDisplayName, 'Alice');
    expect(repo.lastAcceptedMyDisplayName, 'Bob');
  });

  test('propagates repository exception', () {
    repo.error = Exception('friendship already exists');
    expect(
      () => usecase(
        requestId: 'req-2',
        fromUid: 'uid-1',
        fromDisplayName: 'Alice',
        myDisplayName: 'Bob',
      ),
      throwsA(isA<Exception>()),
    );
  });
}
