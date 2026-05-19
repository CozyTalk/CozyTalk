import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/admin/domain/entities/admin_report.dart';
import 'package:mobile/features/admin/domain/entities/admin_report_outcome.dart';

void main() {
  group('AdminReport', () {
    final date = DateTime(2025, 3, 15);

    test('constructs with required fields and empty defaults', () {
      final report = AdminReport(
        id: 'r1',
        status: 'pending',
        reporterId: 'uid-a',
        reportedUserId: 'uid-b',
        sessionId: 'ses1',
        reportType: 'spam',
        reason: 'Sending scam links',
        createdAt: date,
        reporterName: 'UserA',
        reportedName: 'UserB',
        reportedInterest: 'coding',
      );
      expect(report.id, 'r1');
      expect(report.status, 'pending');
      expect(report.contextText, isNull);
      expect(report.contextImageUrls, isEmpty);
      expect(report.chatLogStoragePath, isNull);
      expect(report.outcome, isNull);
    });

    test('constructs with all optional fields', () {
      final outcome = AdminReportOutcome(
        kind: 'banned',
        byName: 'Admin',
        at: date,
      );
      final report = AdminReport(
        id: 'r2',
        status: 'resolved',
        reporterId: 'uid-a',
        reportedUserId: 'uid-b',
        sessionId: 'ses2',
        reportType: 'harassment',
        reason: 'Offensive language',
        contextText: 'Additional context',
        contextImageUrls: ['url1', 'url2'],
        chatLogStoragePath: 'reports/r2/chat_log.json',
        createdAt: date,
        outcome: outcome,
        reporterName: 'Alice',
        reportedName: 'Bob',
        reportedInterest: 'music',
      );
      expect(report.contextText, 'Additional context');
      expect(report.contextImageUrls, ['url1', 'url2']);
      expect(report.chatLogStoragePath, 'reports/r2/chat_log.json');
      expect(report.outcome?.kind, 'banned');
    });
  });
}
