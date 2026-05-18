import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/friends/domain/entities/friend_request.dart';

void main() {
  group('FriendRequestStatus enum', () {
    test('contains all expected values', () {
      expect(
        FriendRequestStatus.values,
        containsAll([
          FriendRequestStatus.pending,
          FriendRequestStatus.accepted,
          FriendRequestStatus.declined,
        ]),
      );
    });

    test('has exactly three values', () {
      expect(FriendRequestStatus.values, hasLength(3));
    });
  });

  group('FriendRequest', () {
    test('constructs with all required fields', () {
      final request = FriendRequest(
        id: 'req-1',
        fromUid: 'uid-1',
        fromDisplayName: 'Alice',
        toUid: 'uid-2',
        toDisplayName: 'Bob',
        status: FriendRequestStatus.pending,
        createdAt: DateTime.fromMillisecondsSinceEpoch(2000),
      );
      expect(request.id, 'req-1');
      expect(request.fromUid, 'uid-1');
      expect(request.fromDisplayName, 'Alice');
      expect(request.toUid, 'uid-2');
      expect(request.toDisplayName, 'Bob');
      expect(request.status, FriendRequestStatus.pending);
      expect(request.createdAt.millisecondsSinceEpoch, 2000);
    });

    test('status can be accepted', () {
      final request = FriendRequest(
        id: 'req-2',
        fromUid: 'uid-1',
        fromDisplayName: 'Alice',
        toUid: 'uid-2',
        toDisplayName: 'Bob',
        status: FriendRequestStatus.accepted,
        createdAt: DateTime(2024),
      );
      expect(request.status, FriendRequestStatus.accepted);
    });

    test('status can be declined', () {
      final request = FriendRequest(
        id: 'req-3',
        fromUid: 'uid-1',
        fromDisplayName: 'Alice',
        toUid: 'uid-2',
        toDisplayName: 'Bob',
        status: FriendRequestStatus.declined,
        createdAt: DateTime(2024),
      );
      expect(request.status, FriendRequestStatus.declined);
    });

    test('preserves exact createdAt', () {
      final dt = DateTime(2025, 3, 15, 8, 0, 0);
      final request = FriendRequest(
        id: 'req-4',
        fromUid: 'u1',
        fromDisplayName: 'Eve',
        toUid: 'u2',
        toDisplayName: 'Frank',
        status: FriendRequestStatus.pending,
        createdAt: dt,
      );
      expect(request.createdAt, dt);
    });
  });
}
