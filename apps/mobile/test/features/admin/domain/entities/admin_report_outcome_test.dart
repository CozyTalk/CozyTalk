import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/admin/domain/entities/admin_report_outcome.dart';

void main() {
  group('AdminReportOutcome', () {
    final date = DateTime(2025, 1, 10);

    test('constructs with required fields', () {
      final outcome = AdminReportOutcome(
        kind: 'banned',
        byName: 'Admin',
        at: date,
      );
      expect(outcome.kind, 'banned');
      expect(outcome.byName, 'Admin');
      expect(outcome.at, date);
      expect(outcome.note, isNull);
    });

    test('constructs with optional note', () {
      final outcome = AdminReportOutcome(
        kind: 'dismissed',
        byName: 'Mod',
        at: date,
        note: 'Not enough evidence',
      );
      expect(outcome.note, 'Not enough evidence');
    });

    test('kind can be reviewed', () {
      final outcome = AdminReportOutcome(
        kind: 'reviewed',
        byName: 'Admin',
        at: date,
      );
      expect(outcome.kind, 'reviewed');
    });
  });
}
