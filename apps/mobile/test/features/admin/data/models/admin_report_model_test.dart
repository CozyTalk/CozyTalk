import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/admin/data/models/admin_report_model.dart';

void main() {
  group('AdminReportOutcomeModel', () {
    group('fromJson', () {
      test('constructs with all fields from ISO string', () {
        final model = AdminReportOutcomeModel.fromJson({
          'kind': 'banned',
          'byName': 'Admin',
          'at': '2025-01-10T00:00:00.000Z',
          'note': 'Serious offence',
        });
        expect(model.kind, 'banned');
        expect(model.byName, 'Admin');
        expect(model.note, 'Serious offence');
      });

      test('handles null note', () {
        final model = AdminReportOutcomeModel.fromJson({
          'kind': 'dismissed',
          'byName': 'Mod',
          'at': '2025-01-10T00:00:00.000Z',
        });
        expect(model.note, isNull);
      });
    });

    group('toEntity', () {
      test('maps all fields to AdminReportOutcome', () {
        final model = AdminReportOutcomeModel.fromJson({
          'kind': 'reviewed',
          'byName': 'Admin2',
          'at': '2025-02-01T12:00:00.000Z',
          'note': 'Noted',
        });
        final entity = model.toEntity();
        expect(entity.kind, 'reviewed');
        expect(entity.byName, 'Admin2');
        expect(entity.note, 'Noted');
      });
    });
  });

  group('AdminReportModel', () {
    group('fromJson', () {
      test('constructs with all required fields', () {
        final model = AdminReportModel.fromJson({
          'id': 'r1',
          'reporterId': 'u1',
          'reportedUserId': 'u2',
          'sessionId': 's1',
          'reportType': 'spam',
          'reason': 'Scam links',
          'createdAt': '2025-01-15T08:00:00.000Z',
        });
        expect(model.id, 'r1');
        expect(model.reporterId, 'u1');
        expect(model.reportedUserId, 'u2');
        expect(model.sessionId, 's1');
        expect(model.reportType, 'spam');
        expect(model.reason, 'Scam links');
        expect(model.status, 'pending');
        expect(model.contextImageUrls, isEmpty);
        expect(model.outcome, isNull);
        expect(model.reporterName, 'Unknown');
        expect(model.reportedName, 'Unknown');
        expect(model.reportedInterest, '');
      });

      test('constructs with optional fields', () {
        final model = AdminReportModel.fromJson({
          'id': 'r2',
          'reporterId': 'u1',
          'reportedUserId': 'u2',
          'sessionId': 's2',
          'reportType': 'harassment',
          'reason': 'Offensive',
          'contextText': 'Context here',
          'contextImageUrls': ['url1'],
          'chatLogStoragePath': 'reports/r2/chat_log.json',
          'createdAt': '2025-01-15T08:00:00.000Z',
          'status': 'reviewed',
          'reporterName': 'Alice',
          'reportedName': 'Bob',
          'reportedInterest': 'gaming',
        });
        expect(model.contextText, 'Context here');
        expect(model.contextImageUrls, ['url1']);
        expect(model.chatLogStoragePath, 'reports/r2/chat_log.json');
        expect(model.status, 'reviewed');
        expect(model.reporterName, 'Alice');
        expect(model.reportedName, 'Bob');
        expect(model.reportedInterest, 'gaming');
      });

      test('ignores unknown keys', () {
        final model = AdminReportModel.fromJson({
          'id': 'r3',
          'reporterId': 'u1',
          'reportedUserId': 'u2',
          'sessionId': 's3',
          'reportType': 'other',
          'reason': 'Other',
          'createdAt': '2025-01-15T08:00:00.000Z',
          'unknownField': 'ignored',
        });
        expect(model.id, 'r3');
      });
    });

    group('toEntity', () {
      test('normalizes pending status', () {
        final model = AdminReportModel.fromJson({
          'id': 'r1',
          'reporterId': 'u1',
          'reportedUserId': 'u2',
          'sessionId': 's1',
          'reportType': 'spam',
          'reason': 'Spam',
          'createdAt': '2025-01-15T08:00:00.000Z',
          'status': 'pending',
        });
        expect(model.toEntity().status, 'pending');
      });

      test('normalizes reviewed status to resolved', () {
        final model = AdminReportModel.fromJson({
          'id': 'r2',
          'reporterId': 'u1',
          'reportedUserId': 'u2',
          'sessionId': 's2',
          'reportType': 'spam',
          'reason': 'Spam',
          'createdAt': '2025-01-15T08:00:00.000Z',
          'status': 'reviewed',
        });
        expect(model.toEntity().status, 'resolved');
      });

      test('normalizes dismissed status to resolved', () {
        final model = AdminReportModel.fromJson({
          'id': 'r3',
          'reporterId': 'u1',
          'reportedUserId': 'u2',
          'sessionId': 's3',
          'reportType': 'spam',
          'reason': 'Spam',
          'createdAt': '2025-01-15T08:00:00.000Z',
          'status': 'dismissed',
        });
        expect(model.toEntity().status, 'resolved');
      });

      test('maps all fields to AdminReport entity', () {
        final model = AdminReportModel.fromJson({
          'id': 'r4',
          'reporterId': 'u1',
          'reportedUserId': 'u2',
          'sessionId': 's4',
          'reportType': 'harassment',
          'reason': 'Offensive',
          'contextImageUrls': ['url1', 'url2'],
          'createdAt': '2025-01-15T08:00:00.000Z',
          'reporterName': 'Alice',
          'reportedName': 'Bob',
          'reportedInterest': 'music',
        });
        final entity = model.toEntity();
        expect(entity.id, 'r4');
        expect(entity.reportType, 'harassment');
        expect(entity.contextImageUrls, ['url1', 'url2']);
        expect(entity.reporterName, 'Alice');
        expect(entity.reportedName, 'Bob');
        expect(entity.reportedInterest, 'music');
      });
    });
  });
}
