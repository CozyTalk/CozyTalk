import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/admin/domain/entities/admin_user.dart';
import 'package:mobile/features/admin/presentation/providers/admin_provider.dart';

AdminUser _makeUser(String uid, {bool banned = false}) => AdminUser(
  uid: uid,
  displayName: 'Alice',
  interest: 'coding',
  banned: banned,
  online: false,
  createdAt: DateTime(2024, 1, 1),
);

void main() {
  group('AdminUsersState', () {
    test('initial state has sensible defaults', () {
      const state = AdminUsersState();
      expect(state.status, AdminUsersStatus.idle);
      expect(state.users, isEmpty);
      expect(state.isSubmitting, isFalse);
      expect(state.error, isNull);
      expect(state.actionError, isNull);
    });

    test('copyWith updates status', () {
      const state = AdminUsersState();
      final updated = state.copyWith(status: AdminUsersStatus.loading);
      expect(updated.status, AdminUsersStatus.loading);
    });

    test('copyWith updates users list', () {
      const state = AdminUsersState();
      final updated = state.copyWith(users: [_makeUser('u1')]);
      expect(updated.users.length, 1);
      expect(updated.users.first.uid, 'u1');
    });

    test('copyWith updates isSubmitting', () {
      const state = AdminUsersState();
      final updated = state.copyWith(isSubmitting: true);
      expect(updated.isSubmitting, isTrue);
    });

    test('copyWith sets error', () {
      const state = AdminUsersState();
      final updated = state.copyWith(error: 'Failed to load');
      expect(updated.error, 'Failed to load');
    });

    test('copyWith clears error with explicit null (sentinel)', () {
      final state = AdminUsersState(error: 'old');
      final cleared = state.copyWith(error: null);
      expect(cleared.error, isNull);
    });

    test('copyWith preserves error when not passed', () {
      final state = AdminUsersState(error: 'kept');
      final updated = state.copyWith(isSubmitting: false);
      expect(updated.error, 'kept');
    });

    test('copyWith sets actionError', () {
      const state = AdminUsersState();
      final updated = state.copyWith(actionError: 'ban failed');
      expect(updated.actionError, 'ban failed');
    });

    test('copyWith clears actionError with explicit null (sentinel)', () {
      final state = AdminUsersState(actionError: 'ae');
      final cleared = state.copyWith(actionError: null);
      expect(cleared.actionError, isNull);
    });

    test('copyWith preserves actionError when not passed', () {
      final state = AdminUsersState(actionError: 'ae');
      final updated = state.copyWith(isSubmitting: false);
      expect(updated.actionError, 'ae');
    });

    test('copyWith without args preserves all fields', () {
      final user = _makeUser('u1');
      final state = AdminUsersState(
        status: AdminUsersStatus.loaded,
        users: [user],
        isSubmitting: true,
        error: 'e',
        actionError: 'ae',
      );
      final copy = state.copyWith();
      expect(copy.status, AdminUsersStatus.loaded);
      expect(copy.users.length, 1);
      expect(copy.isSubmitting, isTrue);
      expect(copy.error, 'e');
      expect(copy.actionError, 'ae');
    });

    test('users list can contain mix of banned and active users', () {
      final state = AdminUsersState(
        users: [
          _makeUser('u1'),
          _makeUser('u2', banned: true),
          _makeUser('u3'),
        ],
      );
      expect(state.users.where((u) => u.banned).length, 1);
      expect(state.users.where((u) => !u.banned).length, 2);
    });
  });

  group('AdminUsersStatus enum', () {
    test('contains exactly 4 values', () {
      expect(
        AdminUsersStatus.values,
        containsAll([
          AdminUsersStatus.idle,
          AdminUsersStatus.loading,
          AdminUsersStatus.loaded,
          AdminUsersStatus.error,
        ]),
      );
      expect(AdminUsersStatus.values.length, 4);
    });
  });
}
