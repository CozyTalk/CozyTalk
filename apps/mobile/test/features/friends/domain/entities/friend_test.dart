import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/friends/domain/entities/friend.dart';

void main() {
  group('Friend', () {
    test('constructs with all required fields', () {
      final friend = Friend(
        friendshipId: 'uid-1_uid-2',
        friendUid: 'uid-2',
        friendDisplayName: 'Bob',
        chatRoomId: 'uid-1_uid-2',
        friendedAt: DateTime.fromMillisecondsSinceEpoch(1000),
      );
      expect(friend.friendshipId, 'uid-1_uid-2');
      expect(friend.friendUid, 'uid-2');
      expect(friend.friendDisplayName, 'Bob');
      expect(friend.chatRoomId, 'uid-1_uid-2');
      expect(friend.friendedAt.millisecondsSinceEpoch, 1000);
    });

    test('chatRoomId equals friendshipId for same-pair friendships', () {
      final friend = Friend(
        friendshipId: 'aaa_bbb',
        friendUid: 'bbb',
        friendDisplayName: 'Carol',
        chatRoomId: 'aaa_bbb',
        friendedAt: DateTime(2024),
      );
      expect(friend.chatRoomId, friend.friendshipId);
    });

    test('preserves empty displayName', () {
      final friend = Friend(
        friendshipId: 'f1',
        friendUid: 'u1',
        friendDisplayName: '',
        chatRoomId: 'f1',
        friendedAt: DateTime(2024),
      );
      expect(friend.friendDisplayName, '');
    });

    test('friendedAt preserves exact DateTime', () {
      final dt = DateTime(2024, 6, 15, 10, 30, 0);
      final friend = Friend(
        friendshipId: 'f2',
        friendUid: 'u2',
        friendDisplayName: 'Dan',
        chatRoomId: 'f2',
        friendedAt: dt,
      );
      expect(friend.friendedAt, dt);
    });
  });
}
