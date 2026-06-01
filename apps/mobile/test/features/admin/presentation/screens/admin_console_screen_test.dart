import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/admin/domain/entities/admin_report.dart';
import 'package:mobile/features/admin/domain/entities/admin_user.dart';
import 'package:mobile/features/admin/presentation/providers/admin_provider.dart';
import 'package:mobile/screens/admin_console_screen.dart';

// ─── Fake notifiers ─────────────────────────────────────────────────────────

class _FakeReportsNotifier extends AdminReportsNotifier {
  final AdminReportsState _initial;
  int resolveCount = 0;
  int chatLogCount = 0;

  _FakeReportsNotifier([this._initial = const AdminReportsState()]);

  @override
  AdminReportsState build() => _initial;

  @override
  Future<void> resolveReport(
    String reportId, {
    required String action,
    String? note,
  }) async {
    resolveCount++;
  }

  @override
  Future<String?> getChatLogUrl(String reportId) async {
    chatLogCount++;
    return null;
  }
}

class _FakeUsersNotifier extends AdminUsersNotifier {
  final AdminUsersState _initial;
  int banCount = 0;
  int unbanCount = 0;

  _FakeUsersNotifier([this._initial = const AdminUsersState()]);

  @override
  AdminUsersState build() => _initial;

  @override
  Future<void> banUser({
    required String uid,
    required String reason,
    required String duration,
    String? note,
    String? reportId,
  }) async {
    banCount++;
  }

  @override
  Future<void> unbanUser(String uid) async {
    unbanCount++;
  }
}

// ─── Test helpers ────────────────────────────────────────────────────────────

AdminReport _makeReport(String id) => AdminReport(
  id: id,
  status: 'pending',
  reporterId: 'u1',
  reportedUserId: 'u2',
  sessionId: 's1',
  reportType: 'spam',
  reason: 'Sending scam links',
  createdAt: DateTime(2025, 1, 15),
  reporterName: 'Alice',
  reportedName: 'Bob',
  reportedInterest: 'gaming',
);

AdminUser _makeUser(String uid, {bool banned = false, bool online = false}) =>
    AdminUser(
      uid: uid,
      displayName: 'User $uid',
      interest: 'coding',
      banned: banned,
      online: online,
      createdAt: DateTime(2024, 6, 1),
      banReason: banned ? 'Spam' : null,
      banDuration: banned ? '7 Days' : null,
      bannedAt: banned ? DateTime(2025, 1, 1) : null,
      bannedByName: banned ? 'Admin' : null,
    );

Widget _buildScreen({
  _FakeReportsNotifier? reports,
  _FakeUsersNotifier? users,
}) {
  return ProviderScope(
    overrides: [
      adminOnlineCountProvider.overrideWith((ref) => Stream.value(0)),
      adminReportsProvider.overrideWith(
        () => reports ?? _FakeReportsNotifier(),
      ),
      adminUsersProvider.overrideWith(() => users ?? _FakeUsersNotifier()),
    ],
    child: const MaterialApp(home: AdminConsoleScreen()),
  );
}

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  group('AdminConsoleScreen', () {
    testWidgets('renders Reports, Users, and Banned tab labels', (
      tester,
    ) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      expect(find.text('Reports'), findsWidgets);
      expect(find.text('Users'), findsWidgets);
      expect(find.text('Banned'), findsWidgets);
    });

    testWidgets('shows search bar', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('renders with empty state — no crash', (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          reports: _FakeReportsNotifier(
            const AdminReportsState(status: AdminReportsStatus.loaded),
          ),
          users: _FakeUsersNotifier(
            const AdminUsersState(status: AdminUsersStatus.loaded),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(AdminConsoleScreen), findsOneWidget);
    });

    testWidgets('renders pending report count in header', (tester) async {
      final reports = _FakeReportsNotifier(
        AdminReportsState(
          status: AdminReportsStatus.loaded,
          reports: [_makeReport('r1'), _makeReport('r2'), _makeReport('r3')],
        ),
      );
      await tester.pumpWidget(_buildScreen(reports: reports));
      await tester.pumpAndSettle();

      expect(find.text('3'), findsWidgets);
    });

    testWidgets('tapping Users tab shows Users content', (tester) async {
      final users = _FakeUsersNotifier(
        AdminUsersState(
          status: AdminUsersStatus.loaded,
          users: [_makeUser('u1'), _makeUser('u2')],
        ),
      );
      await tester.pumpWidget(_buildScreen(users: users));
      await tester.pump();

      final usersTabs = find.text('Users');
      await tester.tap(usersTabs.first);
      await tester.pumpAndSettle();

      expect(find.text('User u1'), findsOneWidget);
      expect(find.text('User u2'), findsOneWidget);
    });

    testWidgets('tapping Banned tab shows banned users', (tester) async {
      final users = _FakeUsersNotifier(
        AdminUsersState(
          status: AdminUsersStatus.loaded,
          users: [_makeUser('u1'), _makeUser('u2', banned: true)],
        ),
      );
      await tester.pumpWidget(_buildScreen(users: users));
      await tester.pump();

      final bannedTabs = find.text('Banned');
      await tester.tap(bannedTabs.first);
      await tester.pumpAndSettle();

      expect(find.text('User u2'), findsOneWidget);
    });

    testWidgets('search input filters by typing', (tester) async {
      final users = _FakeUsersNotifier(
        AdminUsersState(
          status: AdminUsersStatus.loaded,
          users: [_makeUser('alice'), _makeUser('bob')],
        ),
      );
      await tester.pumpWidget(_buildScreen(users: users));
      await tester.pump();

      await tester.tap(find.text('Users').first);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'alice');
      await tester.pump();

      expect(find.text('User alice'), findsOneWidget);
      expect(find.text('User bob'), findsNothing);
    });

    testWidgets('profile icon button is present in header', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      expect(find.byIcon(Icons.person), findsOneWidget);
    });
  });
}
