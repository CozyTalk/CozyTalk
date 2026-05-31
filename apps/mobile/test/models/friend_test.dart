import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/friend.dart';

void main() {
  group('RoomInfo', () {
    test('constructs with required roomId', () {
      const room = RoomInfo(
        roomId: 'abc12',
        name: 'Kao Tapu',
        thumbnail: 'assets/images/backgrounds/kao_tapu.png',
        current: 2,
        max: 5,
      );
      expect(room.roomId, 'abc12');
      expect(room.name, 'Kao Tapu');
      expect(room.thumbnail, 'assets/images/backgrounds/kao_tapu.png');
      expect(room.current, 2);
      expect(room.max, 5);
      expect(room.isLocked, isFalse);
    });

    test('isFull true when current >= max', () {
      const full = RoomInfo(
        roomId: 'r1',
        name: 'X',
        thumbnail: 'x.png',
        current: 5,
        max: 5,
      );
      expect(full.isFull, isTrue);
    });

    test('isFull false when current < max', () {
      const notFull = RoomInfo(
        roomId: 'r1',
        name: 'X',
        thumbnail: 'x.png',
        current: 3,
        max: 5,
      );
      expect(notFull.isFull, isFalse);
    });

    test('isOneOnOne true when max == 2', () {
      const oneVsOne = RoomInfo(
        roomId: 'r1',
        name: 'X',
        thumbnail: 'x.png',
        current: 1,
        max: 2,
      );
      expect(oneVsOne.isOneOnOne, isTrue);
    });

    test('canJoin true when not full, not locked, not 1v1', () {
      const room = RoomInfo(
        roomId: 'r1',
        name: 'X',
        thumbnail: 'x.png',
        current: 3,
        max: 5,
      );
      expect(room.canJoin, isTrue);
    });

    test('canJoin false when locked', () {
      const room = RoomInfo(
        roomId: 'r1',
        name: 'X',
        thumbnail: 'x.png',
        current: 3,
        max: 5,
        isLocked: true,
      );
      expect(room.canJoin, isFalse);
    });

    test('canJoin false when full', () {
      const room = RoomInfo(
        roomId: 'r1',
        name: 'X',
        thumbnail: 'x.png',
        current: 5,
        max: 5,
      );
      expect(room.canJoin, isFalse);
    });

    test('canJoin false for 1v1 rooms even when not full', () {
      const room = RoomInfo(
        roomId: 'r1',
        name: 'X',
        thumbnail: 'x.png',
        current: 1,
        max: 2,
      );
      expect(room.canJoin, isFalse);
    });
  });
}
