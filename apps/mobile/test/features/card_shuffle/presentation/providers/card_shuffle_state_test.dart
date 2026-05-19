import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/card_shuffle/domain/entities/icebreaker_question.dart';
import 'package:mobile/features/card_shuffle/presentation/providers/card_shuffle_provider.dart';

const _question = IcebreakerQuestion(
  id: 'q001',
  text: 'What changed your life?',
  category: 'defining moments',
  depth: 'deep',
  tags: ['introspective'],
);

void main() {
  group('CardShuffleState', () {
    test('initial state has null question, false isLoading, null error', () {
      const state = CardShuffleState();
      expect(state.currentQuestion, isNull);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
    });

    test('copyWith updates isLoading', () {
      const state = CardShuffleState();
      final updated = state.copyWith(isLoading: true);
      expect(updated.isLoading, isTrue);
      expect(updated.currentQuestion, isNull);
      expect(updated.error, isNull);
    });

    test('copyWith sets currentQuestion', () {
      const state = CardShuffleState();
      final updated = state.copyWith(currentQuestion: _question);
      expect(updated.currentQuestion?.id, 'q001');
    });

    test('copyWith clears currentQuestion with explicit null (sentinel)', () {
      final state = CardShuffleState(currentQuestion: _question);
      final cleared = state.copyWith(currentQuestion: null);
      expect(cleared.currentQuestion, isNull);
    });

    test('copyWith preserves currentQuestion when not specified', () {
      final state = CardShuffleState(currentQuestion: _question);
      final updated = state.copyWith(isLoading: true);
      expect(updated.currentQuestion?.id, 'q001');
    });

    test('copyWith sets error', () {
      const state = CardShuffleState();
      final updated = state.copyWith(error: 'Failed to draw card');
      expect(updated.error, 'Failed to draw card');
    });

    test('copyWith clears error with explicit null (sentinel)', () {
      final state = CardShuffleState(error: 'old error');
      final cleared = state.copyWith(error: null);
      expect(cleared.error, isNull);
    });

    test('copyWith without arguments preserves all fields', () {
      final state = CardShuffleState(
        currentQuestion: _question,
        isLoading: true,
        error: 'e',
      );
      final copy = state.copyWith();
      expect(copy.currentQuestion?.id, 'q001');
      expect(copy.isLoading, isTrue);
      expect(copy.error, 'e');
    });
  });
}
