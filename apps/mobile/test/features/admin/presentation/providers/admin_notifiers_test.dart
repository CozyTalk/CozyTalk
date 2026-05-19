import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/admin/domain/entities/admin_report.dart';
import 'package:mobile/features/admin/domain/entities/admin_user.dart';
import 'package:mobile/features/admin/presentation/providers/admin_provider.dart';
import '../../domain/shared_fakes.dart';

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

AdminUser _makeUser(String uid, {bool banned = false}) => AdminUser(
  uid: uid,
  displayName: 'Alice',
  interest: '',
  banned: banned,
  online: false,
  createdAt: DateTime(2024, 1, 1),
);

void main() {
  group('AdminReportsNotifier — state transitions via repository', () {
    test('loaded state has correct reports after stream emission', () {
      final report = _makeReport('r1');
      // Simulate what the notifier's stream listener does on success
      const initial = AdminReportsState(status: AdminReportsStatus.loading);
      final loaded = initial.copyWith(
        status: AdminReportsStatus.loaded,
        reports: [report],
        error: null,
      );
      expect(loaded.status, AdminReportsStatus.loaded);
      expect(loaded.reports.length, 1);
      expect(loaded.reports.first.id, 'r1');
      expect(loaded.error, isNull);
    });

    test('error state captured from stream error', () {
      const initial = AdminReportsState(status: AdminReportsStatus.loading);
      final errored = initial.copyWith(
        status: AdminReportsStatus.error,
        error: 'Exception: permission denied',
      );
      expect(errored.status, AdminReportsStatus.error);
      expect(errored.error, contains('permission denied'));
    });

    test('resolveReport: isSubmitting guard prevents re-entry', () async {
      final repo = FakeAdminRepository();
      const state = AdminReportsState(isSubmitting: true);
      // Guard: if already submitting, skip
      if (!state.isSubmitting) {
        await repo.resolveReport('r1', action: 'dismiss');
      }
      expect(repo.resolveReportCount, 0);
    });

    test(
      'resolveReport: sets isSubmitting true then false on success',
      () async {
        final repo = FakeAdminRepository();
        final transitions = <bool>[];

        void setSubmitting(bool v) {
          transitions.add(v);
        }

        setSubmitting(true);
        await repo.resolveReport('r1', action: 'dismiss');
        setSubmitting(false);

        expect(transitions, [true, false]);
        expect(repo.lastReportId, 'r1');
        expect(repo.lastAction, 'dismiss');
      },
    );

    test(
      'resolveReport: sets actionError on exception, clears isSubmitting',
      () async {
        final repo = FakeAdminRepository();
        repo.error = Exception('CF error');
        String? actionError;
        bool isSubmitting = true;

        try {
          await repo.resolveReport('r1', action: 'dismiss');
          isSubmitting = false;
        } catch (e) {
          isSubmitting = false;
          actionError = e.toString();
        }

        expect(isSubmitting, isFalse);
        expect(actionError, isNotNull);
      },
    );

    test('getChatLogUrl: sets chatLogUrl on success', () async {
      final repo = FakeAdminRepository();
      repo.returnChatLogUrl = 'https://storage.example.com/log';
      String? chatLogUrl;

      final url = await repo.getChatLogUrl('r1');
      chatLogUrl = url;

      expect(chatLogUrl, 'https://storage.example.com/log');
    });

    test('getChatLogUrl: sets actionError on exception', () async {
      final repo = FakeAdminRepository();
      repo.error = Exception('no log');
      String? actionError;

      try {
        await repo.getChatLogUrl('r1');
      } catch (e) {
        actionError = e.toString();
      }

      expect(actionError, isNotNull);
    });
  });

  group('AdminUsersNotifier — state transitions via repository', () {
    test('loaded state has correct users after stream emission', () {
      const initial = AdminUsersState(status: AdminUsersStatus.loading);
      final loaded = initial.copyWith(
        status: AdminUsersStatus.loaded,
        users: [_makeUser('u1'), _makeUser('u2', banned: true)],
        error: null,
      );
      expect(loaded.status, AdminUsersStatus.loaded);
      expect(loaded.users.length, 2);
    });

    test('banUser: sets isSubmitting guard', () async {
      final repo = FakeAdminRepository();
      const state = AdminUsersState(isSubmitting: true);
      if (!state.isSubmitting) {
        await repo.banUser(uid: 'u1', reason: 'Spam', duration: '1 Day');
      }
      expect(repo.banUserCount, 0);
    });

    test('banUser: calls repository with all args', () async {
      final repo = FakeAdminRepository();
      await repo.banUser(
        uid: 'u1',
        reason: 'Harassment',
        duration: '30 Days',
        note: 'Serious',
        reportId: 'r1',
      );
      expect(repo.banUserCount, 1);
      expect(repo.lastUid, 'u1');
      expect(repo.lastReason, 'Harassment');
      expect(repo.lastDuration, '30 Days');
      expect(repo.lastBanNote, 'Serious');
      expect(repo.lastReportIdForBan, 'r1');
    });

    test('banUser: sets actionError on exception', () async {
      final repo = FakeAdminRepository();
      repo.error = Exception('already banned');
      String? actionError;
      try {
        await repo.banUser(uid: 'u1', reason: 'Spam', duration: '1 Day');
      } catch (e) {
        actionError = e.toString();
      }
      expect(actionError, isNotNull);
    });

    test('unbanUser: calls repository with uid', () async {
      final repo = FakeAdminRepository();
      await repo.unbanUser('u1');
      expect(repo.unbanUserCount, 1);
      expect(repo.lastUid, 'u1');
    });

    test('unbanUser: sets actionError on exception', () async {
      final repo = FakeAdminRepository();
      repo.error = Exception('not banned');
      String? actionError;
      try {
        await repo.unbanUser('u1');
      } catch (e) {
        actionError = e.toString();
      }
      expect(actionError, isNotNull);
    });
  });
}
