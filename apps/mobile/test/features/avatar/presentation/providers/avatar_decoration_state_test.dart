import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/avatar/domain/entities/avatar_decoration.dart';
import 'package:mobile/features/avatar/presentation/providers/avatar_decoration_provider.dart';

void main() {
  group('AvatarDecorationState', () {
    test('initial state has idle status, null decoration, null error', () {
      const state = AvatarDecorationState();
      expect(state.status, AvatarDecorationStatus.idle);
      expect(state.decoration, isNull);
      expect(state.error, isNull);
    });

    test('copyWith updates status', () {
      const state = AvatarDecorationState();
      final updated = state.copyWith(status: AvatarDecorationStatus.loading);
      expect(updated.status, AvatarDecorationStatus.loading);
      expect(updated.decoration, isNull);
      expect(updated.error, isNull);
    });

    test('copyWith sets decoration', () {
      const state = AvatarDecorationState();
      const decoration = AvatarDecoration(hatKey: 'Crown', moodKey: 'Happy');
      final updated = state.copyWith(decoration: decoration);
      expect(updated.decoration?.hatKey, 'Crown');
      expect(updated.decoration?.moodKey, 'Happy');
    });

    test('copyWith clears decoration with explicit null (sentinel)', () {
      const decoration = AvatarDecoration(hatKey: 'Cap');
      final state = AvatarDecorationState(decoration: decoration);
      final cleared = state.copyWith(decoration: null);
      expect(cleared.decoration, isNull);
    });

    test('copyWith sets error', () {
      const state = AvatarDecorationState();
      final updated = state.copyWith(error: 'network error');
      expect(updated.error, 'network error');
    });

    test('copyWith clears error with explicit null (sentinel)', () {
      final state = AvatarDecorationState(error: 'old error');
      final cleared = state.copyWith(error: null);
      expect(cleared.error, isNull);
    });

    test('copyWith without arguments preserves all fields', () {
      const decoration = AvatarDecoration(hatKey: 'Beanie', moodKey: 'Sad');
      final state = AvatarDecorationState(
        status: AvatarDecorationStatus.saving,
        decoration: decoration,
        error: 'e',
      );
      final copy = state.copyWith();
      expect(copy.status, AvatarDecorationStatus.saving);
      expect(copy.decoration?.hatKey, 'Beanie');
      expect(copy.error, 'e');
    });

    test('copyWith status update preserves decoration and error', () {
      const decoration = AvatarDecoration(hatKey: 'Crown');
      final state = AvatarDecorationState(
        status: AvatarDecorationStatus.loading,
        decoration: decoration,
        error: 'e',
      );
      final updated = state.copyWith(status: AvatarDecorationStatus.idle);
      expect(updated.status, AvatarDecorationStatus.idle);
      expect(updated.decoration?.hatKey, 'Crown');
      expect(updated.error, 'e');
    });

    test('AvatarDecorationStatus contains all four values', () {
      expect(
        AvatarDecorationStatus.values,
        containsAll([
          AvatarDecorationStatus.idle,
          AvatarDecorationStatus.loading,
          AvatarDecorationStatus.saving,
          AvatarDecorationStatus.error,
        ]),
      );
      expect(AvatarDecorationStatus.values.length, 4);
    });
  });
}
