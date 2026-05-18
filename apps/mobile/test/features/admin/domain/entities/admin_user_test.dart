import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/admin/domain/entities/admin_ban_record.dart';
import 'package:mobile/features/admin/domain/entities/admin_user.dart';

void main() {
  group('AdminUser', () {
    final createdAt = DateTime(2024, 6, 1);

    test('constructs with required fields and defaults', () {
      final user = AdminUser(
        uid: 'u1',
        displayName: 'Alice',
        interest: 'gaming',
        banned: false,
        online: true,
        createdAt: createdAt,
      );
      expect(user.uid, 'u1');
      expect(user.displayName, 'Alice');
      expect(user.email, isNull);
      expect(user.interest, 'gaming');
      expect(user.banned, isFalse);
      expect(user.online, isTrue);
      expect(user.banHistory, isEmpty);
      expect(user.banReason, isNull);
    });

    test('constructs banned user with all ban fields', () {
      final bannedAt = DateTime(2025, 1, 1);
      final banExpiresAt = DateTime(2025, 1, 8);
      final record = AdminBanRecord(
        reason: 'Spam',
        duration: '7 Days',
        bannedAt: bannedAt,
        bannedByName: 'Admin',
      );
      final user = AdminUser(
        uid: 'u2',
        displayName: 'Bob',
        email: 'bob@example.com',
        interest: '',
        banned: true,
        online: false,
        createdAt: createdAt,
        banReason: 'Spam',
        banDuration: '7 Days',
        bannedAt: bannedAt,
        banExpiresAt: banExpiresAt,
        bannedByName: 'Admin',
        banNote: 'First offence',
        banHistory: [record],
      );
      expect(user.banned, isTrue);
      expect(user.banReason, 'Spam');
      expect(user.banDuration, '7 Days');
      expect(user.bannedAt, bannedAt);
      expect(user.banExpiresAt, banExpiresAt);
      expect(user.bannedByName, 'Admin');
      expect(user.banNote, 'First offence');
      expect(user.banHistory.length, 1);
    });
  });
}
