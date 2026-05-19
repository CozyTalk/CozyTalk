import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/card_shuffle/data/datasources/card_shuffle_datasource.dart';
import 'package:mobile/features/card_shuffle/data/repositories/card_shuffle_repository_impl.dart';
import 'package:mobile/features/card_shuffle/domain/entities/icebreaker_question.dart';

class _FakeCardShuffleDatasource implements CardShuffleDatasource {
  int callCount = 0;
  IcebreakerQuestion? returnValue;
  Exception? error;

  @override
  Future<IcebreakerQuestion> drawCard() async {
    callCount++;
    if (error != null) throw error!;
    return returnValue!;
  }
}

const _question = IcebreakerQuestion(
  id: 'q001',
  text: 'What changed your life?',
  category: 'defining moments',
  depth: 'deep',
  tags: ['introspective'],
);

void main() {
  late _FakeCardShuffleDatasource datasource;
  late CardShuffleRepositoryImpl repository;

  setUp(() {
    datasource = _FakeCardShuffleDatasource();
    repository = CardShuffleRepositoryImpl(datasource);
  });

  group('CardShuffleRepositoryImpl', () {
    test('drawCard calls datasource once', () async {
      datasource.returnValue = _question;
      await repository.drawCard();
      expect(datasource.callCount, 1);
    });

    test('returns the question from datasource', () async {
      datasource.returnValue = _question;
      final result = await repository.drawCard();
      expect(result.id, 'q001');
    });

    test('propagates datasource exceptions', () {
      datasource.error = Exception('storage error');
      expect(() => repository.drawCard(), throwsA(isA<Exception>()));
    });
  });
}
