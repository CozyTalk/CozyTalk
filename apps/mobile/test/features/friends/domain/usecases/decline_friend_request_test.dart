import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/friends/domain/usecases/decline_friend_request.dart';

import '../shared_fakes.dart';

void main() {
  late FakeFriendsRepository repo;
  late DeclineFriendRequest usecase;

  setUp(() {
    repo = FakeFriendsRepository();
    usecase = DeclineFriendRequest(repo);
  });

  test('forwards requestId to repository', () async {
    await usecase(requestId: 'req-5');
    expect(repo.declineFriendRequestCount, 1);
    expect(repo.lastDeclinedRequestId, 'req-5');
  });

  test('propagates repository exception', () {
    repo.error = Exception('request not found');
    expect(() => usecase(requestId: 'req-bad'), throwsA(isA<Exception>()));
  });
}
