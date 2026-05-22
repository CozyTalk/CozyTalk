import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/word_filter/domain/entities/banned_word.dart';

void main() {
  group('BannedWord', () {
    test('constructs with required fields', () {
      const entity = BannedWord(word: 'badword', language: 'en');
      expect(entity.word, 'badword');
      expect(entity.language, 'en');
    });

    test('accepts Thai language', () {
      const entity = BannedWord(word: 'คำหยาบ', language: 'th');
      expect(entity.word, 'คำหยาบ');
      expect(entity.language, 'th');
    });
  });
}
