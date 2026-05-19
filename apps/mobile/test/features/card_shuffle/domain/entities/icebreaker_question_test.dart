import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/card_shuffle/domain/entities/icebreaker_question.dart';

void main() {
  group('IcebreakerQuestion', () {
    test('constructs with all required fields', () {
      const q = IcebreakerQuestion(
        id: 'q001',
        text: 'What changed your life?',
        category: 'defining moments',
        depth: 'deep',
        tags: ['introspective'],
      );
      expect(q.id, 'q001');
      expect(q.text, 'What changed your life?');
      expect(q.category, 'defining moments');
      expect(q.depth, 'deep');
      expect(q.tags, ['introspective']);
    });

    test('preserves multiple tags', () {
      const q = IcebreakerQuestion(
        id: 'q002',
        text: 'Tell me a story.',
        category: 'experiences',
        depth: 'light',
        tags: ['fun', 'storytelling', 'warmth'],
      );
      expect(q.tags.length, 3);
      expect(q.tags, containsAll(['fun', 'storytelling', 'warmth']));
    });

    test('accepts empty tags list', () {
      const q = IcebreakerQuestion(
        id: 'q003',
        text: 'Any question.',
        category: 'misc',
        depth: 'medium',
        tags: [],
      );
      expect(q.tags, isEmpty);
    });
  });
}
