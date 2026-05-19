import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/admin/data/models/admin_user_model.dart';

void main() {
  group('AdminBanRecordModel', () {
    group('fromJson', () {
      test('constructs with required fields', () {
        final model = AdminBanRecordModel.fromJson({
          'reason': 'Spam',
          'duration': '7 Days',
          'bannedAt': '2025-01-01T00:00:00.000Z',
          'bannedBy': 'admin-uid',
          'bannedByName': 'Admin1',
        });
        expect(model.reason, 'Spam');
        expect(model.duration, '7 Days');
        expect(model.bannedByName, 'Admin1');
        expect(model.expiresAt, isNull);
        expect(model.note, isNull);
        expect(model.unbannedAt, isNull);
        expect(model.unbannedBy, isNull);
      });

      test('constructs with all optional fields', () {
        final model = AdminBanRecordModel.fromJson({
          'reason': 'Harassment',
          'duration': '30 Days',
          'bannedAt': '2025-01-01T00:00:00.000Z',
          'bannedBy': 'admin-uid',
          'bannedByName': 'Admin2',
          'expiresAt': '2025-01-31T00:00:00.000Z',
          'note': 'Warned before',
          'unbannedAt': '2025-01-15T00:00:00.000Z',
          'unbannedBy': 'admin-uid-2',
        });
        expect(model.expiresAt, isNotNull);
        expect(model.note, 'Warned before');
        expect(model.unbannedAt, isNotNull);
        expect(model.unbannedBy, 'admin-uid-2');
      });

      test('null expiresAt stays null', () {
        final model = AdminBanRecordModel.fromJson({
          'reason': 'Spam',
          'duration': 'Permanent',
          'bannedAt': '2025-01-01T00:00:00.000Z',
          'bannedBy': 'admin-uid',
          'bannedByName': 'Admin',
          'expiresAt': null,
        });
        expect(model.expiresAt, isNull);
      });
    });

    group('toEntity', () {
      test('maps to AdminBanRecord entity', () {
        final model = AdminBanRecordModel.fromJson({
          'reason': 'Spam',
          'duration': '7 Days',
          'bannedAt': '2025-01-01T00:00:00.000Z',
          'bannedBy': 'admin-uid',
          'bannedByName': 'Admin',
          'note': 'Note',
        });
        final entity = model.toEntity();
        expect(entity.reason, 'Spam');
        expect(entity.duration, '7 Days');
        expect(entity.bannedByName, 'Admin');
        expect(entity.note, 'Note');
      });
    });
  });

  group('AdminUserModel', () {
    group('fromJson', () {
      test('constructs with required fields and defaults', () {
        final model = AdminUserModel.fromJson({
          'uid': 'u1',
          'displayName': 'Alice',
          'createdAt': '2024-06-01T00:00:00.000Z',
        });
        expect(model.uid, 'u1');
        expect(model.displayName, 'Alice');
        expect(model.interest, '');
        expect(model.banned, isFalse);
        expect(model.online, isFalse);
        expect(model.banHistory, isEmpty);
      });

      test('constructs active banned user', () {
        final model = AdminUserModel.fromJson({
          'uid': 'u2',
          'displayName': 'Bob',
          'interest': 'music',
          'banned': true,
          'createdAt': '2024-06-01T00:00:00.000Z',
          'banReason': 'Spam',
          'banDuration': '7 Days',
          'bannedAt': '2025-01-01T00:00:00.000Z',
          'banExpiresAt': '2025-01-08T00:00:00.000Z',
          'bannedByName': 'Admin',
          'banNote': 'First offence',
        });
        expect(model.banned, isTrue);
        expect(model.banReason, 'Spam');
        expect(model.banDuration, '7 Days');
        expect(model.bannedAt, isNotNull);
        expect(model.banExpiresAt, isNotNull);
        expect(model.bannedByName, 'Admin');
        expect(model.banNote, 'First offence');
      });

      test('parses banHistory list', () {
        final model = AdminUserModel.fromJson({
          'uid': 'u3',
          'displayName': 'Carol',
          'createdAt': '2024-06-01T00:00:00.000Z',
          'banHistory': [
            {
              'reason': 'Spam',
              'duration': '1 Day',
              'bannedAt': '2024-11-01T00:00:00.000Z',
              'bannedBy': 'admin-uid',
              'bannedByName': 'Admin',
            },
          ],
        });
        expect(model.banHistory.length, 1);
        expect(model.banHistory.first.reason, 'Spam');
      });

      test('ignores unknown keys', () {
        final model = AdminUserModel.fromJson({
          'uid': 'u4',
          'displayName': 'Dave',
          'createdAt': '2024-06-01T00:00:00.000Z',
          'role': 'user',
          'extraField': true,
        });
        expect(model.uid, 'u4');
      });
    });

    group('toEntity', () {
      test('maps all fields to AdminUser entity', () {
        final model = AdminUserModel.fromJson({
          'uid': 'u1',
          'displayName': 'Alice',
          'interest': 'gaming',
          'banned': false,
          'online': true,
          'createdAt': '2024-06-01T00:00:00.000Z',
        });
        final entity = model.toEntity();
        expect(entity.uid, 'u1');
        expect(entity.displayName, 'Alice');
        expect(entity.interest, 'gaming');
        expect(entity.banned, isFalse);
        expect(entity.online, isTrue);
        expect(entity.banHistory, isEmpty);
      });

      test('converts banHistory models to entities', () {
        final model = AdminUserModel.fromJson({
          'uid': 'u2',
          'displayName': 'Bob',
          'createdAt': '2024-06-01T00:00:00.000Z',
          'banHistory': [
            {
              'reason': 'Harassment',
              'duration': 'Permanent',
              'bannedAt': '2025-01-01T00:00:00.000Z',
              'bannedBy': 'admin-uid',
              'bannedByName': 'Admin',
            },
          ],
        });
        final entity = model.toEntity();
        expect(entity.banHistory.length, 1);
        expect(entity.banHistory.first.duration, 'Permanent');
      });
    });
  });
}
