import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/admin/domain/entities/admin_ban_record.dart';

void main() {
  group('AdminBanRecord', () {
    final bannedAt = DateTime(2025, 1, 1);
    final expiresAt = DateTime(2025, 1, 8);
    final unbannedAt = DateTime(2025, 1, 5);

    test('constructs with required fields only', () {
      final record = AdminBanRecord(
        reason: 'Spam',
        duration: '7 Days',
        bannedAt: bannedAt,
        bannedByName: 'Admin1',
      );
      expect(record.reason, 'Spam');
      expect(record.duration, '7 Days');
      expect(record.bannedAt, bannedAt);
      expect(record.bannedByName, 'Admin1');
      expect(record.expiresAt, isNull);
      expect(record.note, isNull);
      expect(record.unbannedAt, isNull);
      expect(record.unbannedBy, isNull);
    });

    test('constructs with all optional fields', () {
      final record = AdminBanRecord(
        reason: 'Harassment',
        duration: '30 Days',
        bannedAt: bannedAt,
        expiresAt: expiresAt,
        bannedByName: 'Admin2',
        note: 'Repeated offence',
        unbannedAt: unbannedAt,
        unbannedBy: 'admin-uid-2',
      );
      expect(record.expiresAt, expiresAt);
      expect(record.note, 'Repeated offence');
      expect(record.unbannedAt, unbannedAt);
      expect(record.unbannedBy, 'admin-uid-2');
    });

    test('permanent ban has null expiresAt', () {
      final record = AdminBanRecord(
        reason: 'Spam',
        duration: 'Permanent',
        bannedAt: bannedAt,
        bannedByName: 'Admin',
      );
      expect(record.expiresAt, isNull);
    });
  });
}
