import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/admin/domain/entities/admin_report.dart';
import 'package:mobile/features/admin/presentation/providers/admin_provider.dart';

AdminReport _makeReport(String id) => AdminReport(
  id: id,
  status: 'pending',
  reporterId: 'u1',
  reportedUserId: 'u2',
  sessionId: 's1',
  reportType: 'spam',
  reason: 'Test',
  createdAt: DateTime(2025, 1, 1),
  reporterName: 'Alice',
  reportedName: 'Bob',
  reportedInterest: '',
);

void main() {
  group('AdminReportsState', () {
    test('initial state has sensible defaults', () {
      const state = AdminReportsState();
      expect(state.status, AdminReportsStatus.idle);
      expect(state.reports, isEmpty);
      expect(state.isSubmitting, isFalse);
      expect(state.error, isNull);
      expect(state.actionError, isNull);
      expect(state.chatLogUrl, isNull);
    });

    test('copyWith updates status', () {
      const state = AdminReportsState();
      final updated = state.copyWith(status: AdminReportsStatus.loading);
      expect(updated.status, AdminReportsStatus.loading);
    });

    test('copyWith updates reports list', () {
      const state = AdminReportsState();
      final updated = state.copyWith(reports: [_makeReport('r1')]);
      expect(updated.reports.length, 1);
      expect(updated.reports.first.id, 'r1');
    });

    test('copyWith updates isSubmitting', () {
      const state = AdminReportsState();
      final updated = state.copyWith(isSubmitting: true);
      expect(updated.isSubmitting, isTrue);
    });

    test('copyWith sets error', () {
      const state = AdminReportsState();
      final updated = state.copyWith(error: 'Something failed');
      expect(updated.error, 'Something failed');
    });

    test('copyWith clears error with explicit null (sentinel)', () {
      final state = AdminReportsState(error: 'old error');
      final cleared = state.copyWith(error: null);
      expect(cleared.error, isNull);
    });

    test('copyWith preserves error when not passed', () {
      final state = AdminReportsState(error: 'kept');
      final updated = state.copyWith(isSubmitting: true);
      expect(updated.error, 'kept');
    });

    test('copyWith sets actionError', () {
      const state = AdminReportsState();
      final updated = state.copyWith(actionError: 'action failed');
      expect(updated.actionError, 'action failed');
    });

    test('copyWith clears actionError with explicit null (sentinel)', () {
      final state = AdminReportsState(actionError: 'err');
      final cleared = state.copyWith(actionError: null);
      expect(cleared.actionError, isNull);
    });

    test('copyWith sets chatLogUrl', () {
      const state = AdminReportsState();
      final updated = state.copyWith(chatLogUrl: 'https://example.com/log');
      expect(updated.chatLogUrl, 'https://example.com/log');
    });

    test('copyWith clears chatLogUrl with explicit null (sentinel)', () {
      final state = AdminReportsState(chatLogUrl: 'https://example.com/log');
      final cleared = state.copyWith(chatLogUrl: null);
      expect(cleared.chatLogUrl, isNull);
    });

    test('copyWith preserves chatLogUrl when not passed', () {
      final state = AdminReportsState(chatLogUrl: 'url');
      final updated = state.copyWith(isSubmitting: false);
      expect(updated.chatLogUrl, 'url');
    });

    test('copyWith without args preserves all fields', () {
      final report = _makeReport('r1');
      final state = AdminReportsState(
        status: AdminReportsStatus.loaded,
        reports: [report],
        isSubmitting: true,
        error: 'e',
        actionError: 'ae',
        chatLogUrl: 'url',
      );
      final copy = state.copyWith();
      expect(copy.status, AdminReportsStatus.loaded);
      expect(copy.reports.length, 1);
      expect(copy.isSubmitting, isTrue);
      expect(copy.error, 'e');
      expect(copy.actionError, 'ae');
      expect(copy.chatLogUrl, 'url');
    });
  });

  group('AdminReportsStatus enum', () {
    test('contains exactly 4 values', () {
      expect(
        AdminReportsStatus.values,
        containsAll([
          AdminReportsStatus.idle,
          AdminReportsStatus.loading,
          AdminReportsStatus.loaded,
          AdminReportsStatus.error,
        ]),
      );
      expect(AdminReportsStatus.values.length, 4);
    });
  });
}
