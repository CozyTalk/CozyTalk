import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/card_shuffle/data/models/icebreaker_question_model.dart';

void main() {
  group('IcebreakerQuestionModel', () {
    group('fromJson', () {
      test('constructs from valid json', () {
        final model = IcebreakerQuestionModel.fromJson({
          'id': 'q001',
          'text': 'What changed your life?',
          'category': 'defining moments',
          'depth': 'deep',
          'tags': ['introspective', 'storytelling'],
        });
        expect(model.id, 'q001');
        expect(model.text, 'What changed your life?');
        expect(model.category, 'defining moments');
        expect(model.depth, 'deep');
        expect(model.tags, ['introspective', 'storytelling']);
      });

      test('ignores unknown fields', () {
        final model = IcebreakerQuestionModel.fromJson({
          'id': 'q002',
          'text': 'Any question.',
          'category': 'misc',
          'depth': 'light',
          'tags': [],
          'unknownField': 'should be ignored',
        });
        expect(model.id, 'q002');
        expect(model.tags, isEmpty);
      });
    });

    group('toEntity', () {
      test('maps all fields to IcebreakerQuestion', () {
        const model = IcebreakerQuestionModel(
          id: 'q003',
          text: 'Tell me a story.',
          category: 'experiences',
          depth: 'medium',
          tags: ['fun', 'warmth'],
        );
        final entity = model.toEntity();
        expect(entity.id, 'q003');
        expect(entity.text, 'Tell me a story.');
        expect(entity.category, 'experiences');
        expect(entity.depth, 'medium');
        expect(entity.tags, ['fun', 'warmth']);
      });
    });
  });
}
