import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/domain/entities/auth_user.dart';
import 'package:mobile/features/auth/presentation/providers/auth_provider.dart';

void main() {
  group('AuthState', () {
    test('initial state is idle with null user and error', () {
      const state = AuthState();
      expect(state.status, AuthStatus.idle);
      expect(state.user, isNull);
      expect(state.error, isNull);
    });

    test('copyWith updates status', () {
      const state = AuthState();
      final updated = state.copyWith(status: AuthStatus.loading);
      expect(updated.status, AuthStatus.loading);
    });

    test('copyWith sets user', () {
      const state = AuthState();
      const user = AuthUser(uid: 'u1', email: 'a@b.com');
      final updated = state.copyWith(status: AuthStatus.authenticated, user: user);
      expect(updated.user?.uid, 'u1');
    });

    test('copyWith clears user with explicit null (sentinel)', () {
      const user = AuthUser(uid: 'u1');
      final state = AuthState(status: AuthStatus.authenticated, user: user);
      final cleared = state.copyWith(user: null);
      expect(cleared.user, isNull);
    });

    test('copyWith sets error', () {
      const state = AuthState();
      final updated = state.copyWith(error: 'Invalid email or password.');
      expect(updated.error, 'Invalid email or password.');
    });

    test('copyWith clears error with explicit null (sentinel)', () {
      final state = AuthState(
        status: AuthStatus.unauthenticated,
        error: 'old error',
      );
      final cleared = state.copyWith(error: null);
      expect(cleared.error, isNull);
    });

    test('copyWith without arguments preserves all fields', () {
      const user = AuthUser(uid: 'u1');
      final state = AuthState(
        status: AuthStatus.authenticated,
        user: user,
        error: 'e',
      );
      final copy = state.copyWith();
      expect(copy.status, AuthStatus.authenticated);
      expect(copy.user?.uid, 'u1');
      expect(copy.error, 'e');
    });

    test('authenticated state preserves user across unrelated copyWith', () {
      const user = AuthUser(uid: 'u1');
      final state = AuthState(status: AuthStatus.authenticated, user: user);
      final updated = state.copyWith(error: 'something');
      expect(updated.user?.uid, 'u1');
      expect(updated.status, AuthStatus.authenticated);
    });
  });
}
