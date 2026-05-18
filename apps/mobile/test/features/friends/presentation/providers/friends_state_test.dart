import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/friends/domain/entities/app_user.dart';
import 'package:mobile/features/friends/domain/entities/friend.dart';
import 'package:mobile/features/friends/domain/entities/friend_request.dart';
import 'package:mobile/features/friends/presentation/providers/friends_provider.dart';

void main() {
  group('FriendsState', () {
    test('initial state has empty collections, no loading, no error', () {
      const state = FriendsState();
      expect(state.allUsers, isEmpty);
      expect(state.friends, isEmpty);
      expect(state.incomingRequests, isEmpty);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
    });

    test('copyWith updates isLoading', () {
      const state = FriendsState();
      final updated = state.copyWith(isLoading: true);
      expect(updated.isLoading, isTrue);
      expect(updated.allUsers, isEmpty);
      expect(updated.error, isNull);
    });

    test('copyWith sets error', () {
      const state = FriendsState();
      final updated = state.copyWith(error: 'request failed');
      expect(updated.error, 'request failed');
      expect(updated.isLoading, isFalse);
    });

    test('copyWith clears error with explicit null (sentinel)', () {
      const state = FriendsState(error: 'old error');
      final cleared = state.copyWith(error: null);
      expect(cleared.error, isNull);
    });

    test(
      'copyWith without error argument preserves existing error (sentinel)',
      () {
        const state = FriendsState(error: 'kept error');
        final copy = state.copyWith(isLoading: true);
        expect(copy.error, 'kept error');
      },
    );

    test('copyWith replaces allUsers list', () {
      const state = FriendsState();
      final updated = state.copyWith(
        allUsers: [const AppUser(uid: 'u1', displayName: 'Alice')],
      );
      expect(updated.allUsers, hasLength(1));
      expect(updated.allUsers[0].uid, 'u1');
    });

    test('copyWith replaces friends list', () {
      const state = FriendsState();
      final friend = Friend(
        friendshipId: 'f1',
        friendUid: 'u2',
        friendDisplayName: 'Bob',
        chatRoomId: 'f1',
        friendedAt: DateTime(2024),
      );
      final updated = state.copyWith(friends: [friend]);
      expect(updated.friends, hasLength(1));
      expect(updated.friends[0].friendUid, 'u2');
    });

    test('copyWith replaces incomingRequests list', () {
      const state = FriendsState();
      final request = FriendRequest(
        id: 'req-1',
        fromUid: 'u1',
        fromDisplayName: 'Alice',
        toUid: 'u2',
        toDisplayName: 'Bob',
        status: FriendRequestStatus.pending,
        createdAt: DateTime(2024),
      );
      final updated = state.copyWith(incomingRequests: [request]);
      expect(updated.incomingRequests, hasLength(1));
      expect(updated.incomingRequests[0].id, 'req-1');
    });

    test('copyWith without arguments preserves all fields', () {
      final friend = Friend(
        friendshipId: 'f1',
        friendUid: 'u2',
        friendDisplayName: 'Bob',
        chatRoomId: 'f1',
        friendedAt: DateTime(2024),
      );
      final state = FriendsState(
        allUsers: [const AppUser(uid: 'u1', displayName: 'Alice')],
        friends: [friend],
        isLoading: true,
        error: 'e',
      );
      final copy = state.copyWith();
      expect(copy.allUsers, hasLength(1));
      expect(copy.friends, hasLength(1));
      expect(copy.isLoading, isTrue);
      expect(copy.error, 'e');
    });

    test('copyWith can clear allUsers to empty list', () {
      final state = FriendsState(
        allUsers: [const AppUser(uid: 'u1', displayName: 'Alice')],
      );
      final cleared = state.copyWith(allUsers: []);
      expect(cleared.allUsers, isEmpty);
    });
  });
}
