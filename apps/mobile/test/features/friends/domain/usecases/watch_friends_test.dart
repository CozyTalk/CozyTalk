import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/friends/domain/entities/friend.dart';
import 'package:mobile/features/friends/domain/usecases/watch_friends.dart';

import '../shared_fakes.dart';

void main() {
  late FakeFriendsRepository repo;
  late WatchFriends usecase;

  setUp(() {
    repo = FakeFriendsRepository();
    usecase = WatchFriends(repo);
  });

  test('returns friends stream from repository', () async {
    repo.friends = [
      Friend(
        friendshipId: 'f1',
        friendUid: 'u2',
        friendDisplayName: 'Bob',
        chatRoomId: 'f1',
        friendedAt: DateTime(2024),
      ),
    ];
    final result = await usecase().first;
    expect(result, hasLength(1));
    expect(result[0].friendUid, 'u2');
  });

  test('returns empty stream when no friends', () async {
    final result = await usecase().first;
    expect(result, isEmpty);
  });

  test('propagates stream error from repository', () {
    repo.error = Exception('network error');
    expect(usecase().first, throwsA(isA<Exception>()));
  });
}
