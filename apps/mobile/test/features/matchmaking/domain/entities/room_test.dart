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

  group('copyWith', () {
    test('sets isLocked to true', () {
      final room = Room(
        roomId: 'Rm001',
        roomType: RoomType.public,
        mode: RoomMode.group,
        status: RoomStatus.active,
        maxUsers: 5,
        memberCount: 2,
        users: const ['uid1', 'uid2'],
        isLocked: false,
        createdAt: DateTime(2025),
      );

      expect(room.copyWith(isLocked: true).isLocked, true);
    });

    test('sets isLocked to false', () {
      final room = Room(
        roomId: 'Rm001',
        roomType: RoomType.custom,
        mode: RoomMode.group,
        status: RoomStatus.active,
        maxUsers: 5,
        memberCount: 1,
        users: const ['uid1'],
        isLocked: true,
        createdAt: DateTime(2025),
      );

      expect(room.copyWith(isLocked: false).isLocked, false);
    });

    test('preserves isLocked when called with no args', () {
      final room = Room(
        roomId: 'Rm001',
        roomType: RoomType.public,
        mode: RoomMode.group,
        status: RoomStatus.active,
        maxUsers: 5,
        memberCount: 1,
        users: const ['uid1'],
        isLocked: true,
        createdAt: DateTime(2025),
      );

      expect(room.copyWith().isLocked, true);
    });

    test('preserves all other fields after copyWith', () {
      final created = DateTime(2025, 3, 1);
      final room = Room(
        roomId: 'Rm999',
        roomType: RoomType.custom,
        mode: RoomMode.group,
        status: RoomStatus.active,
        maxUsers: 5,
        memberCount: 2,
        users: const ['uid1', 'uid2'],
        isLocked: false,
        createdAt: created,
        backgroundTheme: 'kao_tapu',
      );

      final updated = room.copyWith(isLocked: true);

      expect(updated.roomId, 'Rm999');
      expect(updated.roomType, RoomType.custom);
      expect(updated.mode, RoomMode.group);
      expect(updated.status, RoomStatus.active);
      expect(updated.maxUsers, 5);
      expect(updated.memberCount, 2);
      expect(updated.users, ['uid1', 'uid2']);
      expect(updated.createdAt, created);
      expect(updated.backgroundTheme, 'kao_tapu');
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
