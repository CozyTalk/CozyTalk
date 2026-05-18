import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/friends/data/models/friend_model.dart';

void main() {
  group('FriendModel', () {
    group('fromJson', () {
      test('constructs with all fields present', () {
        final model = FriendModel.fromJson({
          'id': 'uid-1_uid-2',
          'users': ['uid-1', 'uid-2'],
          'displayNames': {'uid-1': 'Alice', 'uid-2': 'Bob'},
          'chatRoomId': 'uid-1_uid-2',
          'createdAt': 1000,
        });
        expect(model.id, 'uid-1_uid-2');
        expect(model.users, ['uid-1', 'uid-2']);
        expect(model.displayNames, {'uid-1': 'Alice', 'uid-2': 'Bob'});
        expect(model.chatRoomId, 'uid-1_uid-2');
        expect(model.createdAt, 1000);
      });

      test('handles timestamp value of zero', () {
        final model = FriendModel.fromJson({
          'id': 'f1',
          'users': ['u1', 'u2'],
          'displayNames': {'u1': 'X', 'u2': 'Y'},
          'chatRoomId': 'f1',
          'createdAt': 0,
        });
        expect(model.createdAt, 0);
      });
    });

    group('toEntity', () {
      test('extracts the friend UID (not the current user)', () {
        const model = FriendModel(
          id: 'uid-1_uid-2',
          users: ['uid-1', 'uid-2'],
          displayNames: {'uid-1': 'Alice', 'uid-2': 'Bob'},
          chatRoomId: 'uid-1_uid-2',
          createdAt: 5000,
        );
        final friend = model.toEntity('uid-1');
        expect(friend.friendUid, 'uid-2');
        expect(friend.friendDisplayName, 'Bob');
      });

      test('extracts the correct friend when current user is second', () {
        const model = FriendModel(
          id: 'uid-1_uid-2',
          users: ['uid-1', 'uid-2'],
          displayNames: {'uid-1': 'Alice', 'uid-2': 'Bob'},
          chatRoomId: 'uid-1_uid-2',
          createdAt: 0,
        );
        final friend = model.toEntity('uid-2');
        expect(friend.friendUid, 'uid-1');
        expect(friend.friendDisplayName, 'Alice');
      });

      test('maps friendshipId and chatRoomId from model id', () {
        const model = FriendModel(
          id: 'aaa_bbb',
          users: ['aaa', 'bbb'],
          displayNames: {'aaa': 'A', 'bbb': 'B'},
          chatRoomId: 'aaa_bbb',
          createdAt: 0,
        );
        final friend = model.toEntity('aaa');
        expect(friend.friendshipId, 'aaa_bbb');
        expect(friend.chatRoomId, 'aaa_bbb');
      });

      test('converts createdAt millis to friendedAt DateTime', () {
        const model = FriendModel(
          id: 'f1',
          users: ['u1', 'u2'],
          displayNames: {'u1': 'X', 'u2': 'Y'},
          chatRoomId: 'f1',
          createdAt: 1000,
        );
        final friend = model.toEntity('u1');
        expect(friend.friendedAt, DateTime.fromMillisecondsSinceEpoch(1000));
      });

      test('falls back to empty string for unknown friend uid', () {
        const model = FriendModel(
          id: 'f1',
          users: ['u1', 'u1'],
          displayNames: {},
          chatRoomId: 'f1',
          createdAt: 0,
        );
        final friend = model.toEntity('u1');
        expect(friend.friendDisplayName, 'Anonymous');
      });
    });
  });
}
