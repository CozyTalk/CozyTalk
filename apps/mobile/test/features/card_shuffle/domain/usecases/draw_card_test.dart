import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/card_shuffle/domain/entities/icebreaker_question.dart';
import 'package:mobile/features/card_shuffle/domain/repositories/card_shuffle_repository.dart';
import 'package:mobile/features/card_shuffle/domain/usecases/draw_card.dart';

class _FakeCardShuffleRepository implements CardShuffleRepository {
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
  late _FakeCardShuffleRepository repo;
  late DrawCard usecase;

  setUp(() {
    repo = _FakeCardShuffleRepository();
    usecase = DrawCard(repo);
  });

  group('DrawCard', () {
    test('delegates to repository', () async {
      repo.returnValue = _question;
      await usecase();
      expect(repo.callCount, 1);
    });

    test('returns the question from the repository', () async {
      repo.returnValue = _question;
      final result = await usecase();
      expect(result.id, 'q001');
      expect(result.text, 'What changed your life?');
    });

    test('propagates repository exceptions', () {
      repo.error = Exception('draw failed');
      expect(() => usecase(), throwsA(isA<Exception>()));
    });
  });
}
