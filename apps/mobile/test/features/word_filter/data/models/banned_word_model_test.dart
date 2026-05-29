import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/word_filter/data/models/banned_word_model.dart';

void main() {
  group('BannedWordModel', () {
    group('fromJson', () {
      test('maps all fields', () {
        final model = BannedWordModel.fromJson({
          'word': 'badword',
          'language': 'en',
        });
        expect(model.word, 'badword');
        expect(model.language, 'en');
      });

      test('maps Thai language entry', () {
        final model = BannedWordModel.fromJson({
          'word': 'คำหยาบ',
          'language': 'th',
        });
        expect(model.word, 'คำหยาบ');
        expect(model.language, 'th');
      });

      test('ignores unknown fields', () {
        final model = BannedWordModel.fromJson({
          'word': 'test',
          'language': 'en',
          'id': 42,
          'extra': 'ignored',
        });
        expect(model.word, 'test');
        expect(model.language, 'en');
      });

      test('throws when required fields are missing', () {
        expect(() => BannedWordModel.fromJson({}), throwsA(anything));
      });
    });

    group('toEntity', () {
      test('maps fields to BannedWord entity', () {
        const model = BannedWordModel(word: 'badword', language: 'en');
        final entity = model.toEntity();
        expect(entity.word, 'badword');
        expect(entity.language, 'en');
      });
    });
  });
}
