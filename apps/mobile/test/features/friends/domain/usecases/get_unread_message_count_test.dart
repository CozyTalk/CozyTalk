import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/friends/domain/usecases/get_unread_message_count.dart';

import '../shared_fakes.dart';

void main() {
  late FakeFriendsRepository repo;
  late GetUnreadMessageCount usecase;

  setUp(() {
    repo = FakeFriendsRepository();
    usecase = GetUnreadMessageCount(repo);
  });

  test('returns count from repository', () async {
    repo.unreadCountResult = 5;
    final result = await usecase('room-1', sinceMs: 1000, friendUid: 'uid-2');
    expect(result, 5);
  });

  test('returns zero when no unread messages', () async {
    final result = await usecase('room-1', sinceMs: 1000, friendUid: 'uid-2');
    expect(result, 0);
  });

  test('forwards all parameters to repository', () async {
    await usecase('room-abc', sinceMs: 9999, friendUid: 'uid-x');
    expect(repo.lastUnreadCountChatRoomId, 'room-abc');
    expect(repo.lastUnreadCountSinceMs, 9999);
    expect(repo.lastUnreadCountFriendUid, 'uid-x');
  });

  test('propagates repository exception', () {
    repo.error = Exception('permission denied');
    expect(
      () => usecase('room-1', sinceMs: 0, friendUid: 'uid-2'),
      throwsA(isA<Exception>()),
    );
  });
}
