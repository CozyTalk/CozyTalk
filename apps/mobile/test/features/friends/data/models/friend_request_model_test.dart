import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/friends/data/models/friend_request_model.dart';
import 'package:mobile/features/friends/domain/entities/friend_request.dart';

void main() {
  group('FriendRequestModel', () {
    group('fromJson', () {
      test('constructs with all fields present', () {
        final model = FriendRequestModel.fromJson({
          'id': 'req-1',
          'fromUid': 'uid-1',
          'fromDisplayName': 'Alice',
          'toUid': 'uid-2',
          'toDisplayName': 'Bob',
          'status': 'pending',
          'createdAt': 3000,
        });
        expect(model.id, 'req-1');
        expect(model.fromUid, 'uid-1');
        expect(model.fromDisplayName, 'Alice');
        expect(model.toUid, 'uid-2');
        expect(model.toDisplayName, 'Bob');
        expect(model.status, 'pending');
        expect(model.createdAt, 3000);
      });
    });

    group('toEntity', () {
      test('parses status "pending"', () {
        const model = FriendRequestModel(
          id: 'req-1',
          fromUid: 'u1',
          fromDisplayName: 'Alice',
          toUid: 'u2',
          toDisplayName: 'Bob',
          status: 'pending',
          createdAt: 0,
        );
        expect(model.toEntity().status, FriendRequestStatus.pending);
      });

      test('parses status "accepted"', () {
        const model = FriendRequestModel(
          id: 'req-2',
          fromUid: 'u1',
          fromDisplayName: 'Alice',
          toUid: 'u2',
          toDisplayName: 'Bob',
          status: 'accepted',
          createdAt: 0,
        );
        expect(model.toEntity().status, FriendRequestStatus.accepted);
      });

      test('parses status "declined"', () {
        const model = FriendRequestModel(
          id: 'req-3',
          fromUid: 'u1',
          fromDisplayName: 'Alice',
          toUid: 'u2',
          toDisplayName: 'Bob',
          status: 'declined',
          createdAt: 0,
        );
        expect(model.toEntity().status, FriendRequestStatus.declined);
      });

      test('falls back to pending for unknown status string', () {
        const model = FriendRequestModel(
          id: 'req-4',
          fromUid: 'u1',
          fromDisplayName: 'Alice',
          toUid: 'u2',
          toDisplayName: 'Bob',
          status: 'unknown_value',
          createdAt: 0,
        );
        expect(model.toEntity().status, FriendRequestStatus.pending);
      });

      test('maps all fields to FriendRequest entity', () {
        const model = FriendRequestModel(
          id: 'req-5',
          fromUid: 'uid-1',
          fromDisplayName: 'Carol',
          toUid: 'uid-2',
          toDisplayName: 'Dan',
          status: 'pending',
          createdAt: 2000,
        );
        final entity = model.toEntity();
        expect(entity.id, 'req-5');
        expect(entity.fromUid, 'uid-1');
        expect(entity.fromDisplayName, 'Carol');
        expect(entity.toUid, 'uid-2');
        expect(entity.toDisplayName, 'Dan');
        expect(entity.createdAt, DateTime.fromMillisecondsSinceEpoch(2000));
      });
    });
  });
}
