import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/hello/domain/entities/hello_message.dart';
import 'package:mobile/features/hello/presentation/providers/hello_provider.dart';

void main() {
  group('HelloState', () {
    test('initial state has null result, false isLoading, null error', () {
      const state = HelloState();
      expect(state.result, isNull);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
    });

    test('copyWith updates isLoading', () {
      const state = HelloState();
      final updated = state.copyWith(isLoading: true);
      expect(updated.isLoading, isTrue);
      expect(updated.result, isNull);
      expect(updated.error, isNull);
    });

    test('copyWith sets result', () {
      const state = HelloState();
      const msg = HelloMessage(message: 'hi');
      final updated = state.copyWith(result: msg);
      expect(updated.result?.message, 'hi');
    });

    test('copyWith clears result with explicit null (sentinel)', () {
      const msg = HelloMessage(message: 'hi');
      final state = HelloState(result: msg);
      final cleared = state.copyWith(result: null);
      expect(cleared.result, isNull);
    });

    test('copyWith sets error', () {
      const state = HelloState();
      final updated = state.copyWith(error: 'something went wrong');
      expect(updated.error, 'something went wrong');
    });

    test('copyWith clears error with explicit null (sentinel)', () {
      final state = HelloState(error: 'old error');
      final cleared = state.copyWith(error: null);
      expect(cleared.error, isNull);
    });

    test('copyWith without arguments preserves all fields', () {
      const msg = HelloMessage(message: 'keep');
      final state = HelloState(result: msg, isLoading: true, error: 'e');
      final copy = state.copyWith();
      expect(copy.result?.message, 'keep');
      expect(copy.isLoading, isTrue);
      expect(copy.error, 'e');
    });
  });
}
