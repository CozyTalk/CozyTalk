import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/matchmaking/domain/entities/room.dart';

void main() {
  group('Room', () {
    test('constructs with all required fields', () {
      final room = Room(
        roomId: 'Ab3Kz',
        roomType: RoomType.public,
        mode: RoomMode.group,
        status: RoomStatus.active,
        maxUsers: 5,
        memberCount: 2,
        users: const ['uid1', 'uid2'],
        isLocked: false,
        createdAt: DateTime(2025),
      );

      expect(room.roomId, 'Ab3Kz');
      expect(room.roomType, RoomType.public);
      expect(room.mode, RoomMode.group);
      expect(room.status, RoomStatus.active);
      expect(room.maxUsers, 5);
      expect(room.memberCount, 2);
      expect(room.users, ['uid1', 'uid2']);
      expect(room.isLocked, false);
      expect(room.paddingUntil, isNull);
    });

    test('paddingUntil defaults to null when omitted', () {
      final room = Room(
        roomId: 'Xy3Kz',
        roomType: RoomType.custom,
        mode: RoomMode.oneToOne,
        status: RoomStatus.padding,
        maxUsers: 2,
        memberCount: 0,
        users: const [],
        isLocked: true,
        createdAt: DateTime(2025),
      );

      expect(room.paddingUntil, isNull);
    });

    test('accepts non-null paddingUntil', () {
      final deadline = DateTime(2025, 6, 1, 12);
      final room = Room(
        roomId: 'PdRm1',
        roomType: RoomType.public,
        mode: RoomMode.group,
        status: RoomStatus.padding,
        maxUsers: 5,
        memberCount: 0,
        users: const [],
        isLocked: false,
        createdAt: DateTime(2025),
        paddingUntil: deadline,
      );

      expect(room.paddingUntil, deadline);
    });
  });

  group('RoomType', () {
    test('contains exactly public and custom', () {
      expect(RoomType.values, containsAll([RoomType.public, RoomType.custom]));
      expect(RoomType.values, hasLength(2));
    });
  });

  group('RoomMode', () {
    test('contains exactly oneToOne and group', () {
      expect(RoomMode.values, containsAll([RoomMode.oneToOne, RoomMode.group]));
      expect(RoomMode.values, hasLength(2));
    });
  });

  group('RoomStatus', () {
    test('contains exactly active, padding, and expired', () {
      expect(
        RoomStatus.values,
        containsAll([
          RoomStatus.active,
          RoomStatus.padding,
          RoomStatus.expired,
        ]),
      );
      expect(RoomStatus.values, hasLength(3));
    });
  });
}
