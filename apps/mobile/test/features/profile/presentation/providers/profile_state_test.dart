import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/profile/domain/entities/profile_user.dart';
import 'package:mobile/features/profile/presentation/providers/profile_provider.dart';

void main() {
  group('ProfileState', () {
    test('initial state has null profile, not loading, no error', () {
      const state = ProfileState();
      expect(state.profile, isNull);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
      expect(state.successField, isNull);
    });

    test('copyWith updates isLoading', () {
      const state = ProfileState();
      final updated = state.copyWith(isLoading: true);
      expect(updated.isLoading, isTrue);
    });

    test('copyWith sets profile', () {
      const state = ProfileState();
      const user = ProfileUser(uid: 'u1', displayName: 'Alice');
      final updated = state.copyWith(profile: user);
      expect(updated.profile?.uid, 'u1');
      expect(updated.profile?.displayName, 'Alice');
    });

    test('copyWith clears profile with explicit null (sentinel)', () {
      const user = ProfileUser(uid: 'u1');
      final state = ProfileState(profile: user);
      final cleared = state.copyWith(profile: null);
      expect(cleared.profile, isNull);
    });

    test('copyWith sets error', () {
      const state = ProfileState();
      final updated = state.copyWith(error: 'something went wrong');
      expect(updated.error, 'something went wrong');
    });

    test('copyWith clears error with explicit null (sentinel)', () {
      final state = ProfileState(error: 'old error');
      final cleared = state.copyWith(error: null);
      expect(cleared.error, isNull);
    });

    test('copyWith sets successField', () {
      const state = ProfileState();
      final updated = state.copyWith(successField: 'username');
      expect(updated.successField, 'username');
    });

    test('copyWith clears successField with explicit null (sentinel)', () {
      final state = ProfileState(successField: 'username');
      final cleared = state.copyWith(successField: null);
      expect(cleared.successField, isNull);
    });

    test('copyWith without arguments preserves all fields', () {
      const user = ProfileUser(uid: 'u1');
      final state = ProfileState(
        profile: user,
        isLoading: true,
        error: 'e',
        successField: 'interest',
      );
      final copy = state.copyWith();
      expect(copy.profile?.uid, 'u1');
      expect(copy.isLoading, isTrue);
      expect(copy.error, 'e');
      expect(copy.successField, 'interest');
    });

    test('copyWith profile update preserves error and successField', () {
      const user = ProfileUser(uid: 'u1');
      final state = ProfileState(error: 'e', successField: 'thoughts');
      final updated = state.copyWith(profile: user);
      expect(updated.profile?.uid, 'u1');
      expect(updated.error, 'e');
      expect(updated.successField, 'thoughts');
    });
  });
}
