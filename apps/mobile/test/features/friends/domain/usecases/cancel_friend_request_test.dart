import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/friends/domain/usecases/cancel_friend_request.dart';

import '../shared_fakes.dart';

void main() {
  late FakeFriendsRepository repo;
  late CancelFriendRequest usecase;

  setUp(() {
    repo = FakeFriendsRepository();
    usecase = CancelFriendRequest(repo);
  });

  test('forwards toUid to repository', () async {
    await usecase(toUid: 'u2');
    expect(repo.cancelFriendRequestCount, 1);
    expect(repo.lastCancelToUid, 'u2');
  });

  test('propagates repository exception', () {
    repo.error = Exception('not found');
    expect(() => usecase(toUid: 'u2'), throwsA(isA<Exception>()));
  });
}
