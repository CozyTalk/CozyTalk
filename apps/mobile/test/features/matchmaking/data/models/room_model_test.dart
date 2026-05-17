import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/matchmaking/data/models/room_model.dart';
import 'package:mobile/features/matchmaking/domain/entities/room.dart';

Map<String, dynamic> _baseJson() => {
  'roomId': 'Ab3Kz',
  'roomType': 'public',
  'mode': 'group',
  'status': 'active',
  'maxUsers': 5,
  'memberCount': 2,
  'users': ['uid1', 'uid2'],
  'isLocked': false,
  'createdAt': 1_700_000_000_000,
  'paddingUntil': null,
};

void main() {
  group('RoomModel.fromJson', () {
    test('parses all fields correctly', () {
      final model = RoomModel.fromJson(_baseJson());

      expect(model.roomId, 'Ab3Kz');
      expect(model.roomType, 'public');
      expect(model.mode, 'group');
      expect(model.status, 'active');
      expect(model.maxUsers, 5);
      expect(model.memberCount, 2);
      expect(model.users, ['uid1', 'uid2']);
      expect(model.isLocked, false);
      expect(model.createdAt, 1_700_000_000_000);
      expect(model.paddingUntil, isNull);
    });

    test('parses optional paddingUntil as non-null', () {
      final json = _baseJson()..['paddingUntil'] = 1_700_000_300_000;

      final model = RoomModel.fromJson(json);

      expect(model.paddingUntil, 1_700_000_300_000);
    });

    test('ignores extra unknown keys', () {
      final json = _baseJson()..['unknownField'] = 'ignored';

      expect(() => RoomModel.fromJson(json), returnsNormally);
    });

    test('parses roomInterestVector when present', () {
      final json = _baseJson()..['roomInterestVector'] = [0.1, 0.2, 0.3];

      final model = RoomModel.fromJson(json);

      expect(model.roomInterestVector, [0.1, 0.2, 0.3]);
    });

    test('roomInterestVector defaults to null when absent', () {
      final model = RoomModel.fromJson(_baseJson());

      expect(model.roomInterestVector, isNull);
    });
  });

  group('RoomModel.toEntity', () {
    RoomModel modelFrom(Map<String, dynamic> overrides) =>
        RoomModel.fromJson({..._baseJson(), ...overrides});

    test('maps roomType public → RoomType.public', () {
      expect(
        modelFrom({'roomType': 'public'}).toEntity().roomType,
        RoomType.public,
      );
    });

    test('maps roomType custom → RoomType.custom', () {
      expect(
        modelFrom({'roomType': 'custom'}).toEntity().roomType,
        RoomType.custom,
      );
    });

    test('maps mode 1v1 → RoomMode.oneToOne', () {
      expect(modelFrom({'mode': '1v1'}).toEntity().mode, RoomMode.oneToOne);
    });

    test('maps mode group → RoomMode.group', () {
      expect(modelFrom({'mode': 'group'}).toEntity().mode, RoomMode.group);
    });

    test('maps status active → RoomStatus.active', () {
      expect(
        modelFrom({'status': 'active'}).toEntity().status,
        RoomStatus.active,
      );
    });

    test('maps status padding → RoomStatus.padding', () {
      expect(
        modelFrom({'status': 'padding'}).toEntity().status,
        RoomStatus.padding,
      );
    });

    test('maps status expired → RoomStatus.expired', () {
      expect(
        modelFrom({'status': 'expired'}).toEntity().status,
        RoomStatus.expired,
      );
    });

    test('maps unknown status string → RoomStatus.active (safe default)', () {
      expect(
        modelFrom({'status': 'unknown'}).toEntity().status,
        RoomStatus.active,
      );
    });

    test('converts createdAt milliseconds to DateTime', () {
      const ms = 1_700_000_000_000;
      final entity = modelFrom({'createdAt': ms}).toEntity();
      expect(entity.createdAt, DateTime.fromMillisecondsSinceEpoch(ms));
    });

    test('paddingUntil null stays null in entity', () {
      final entity = modelFrom({'paddingUntil': null}).toEntity();
      expect(entity.paddingUntil, isNull);
    });

    test('paddingUntil non-null is converted to DateTime', () {
      const ms = 1_700_000_300_000;
      final entity = modelFrom({'paddingUntil': ms}).toEntity();
      expect(entity.paddingUntil, DateTime.fromMillisecondsSinceEpoch(ms));
    });

    test('users list is preserved', () {
      final entity = modelFrom({
        'users': ['a', 'b', 'c'],
      }).toEntity();
      expect(entity.users, ['a', 'b', 'c']);
    });

    test('maps roomInterestVector to entity when present', () {
      final entity = modelFrom({
        'roomInterestVector': [0.5, 0.6],
      }).toEntity();
      expect(entity.roomInterestVector, [0.5, 0.6]);
    });

    test('roomInterestVector null stays null in entity', () {
      final entity = modelFrom({}).toEntity();
      expect(entity.roomInterestVector, isNull);
    });
  });
}
