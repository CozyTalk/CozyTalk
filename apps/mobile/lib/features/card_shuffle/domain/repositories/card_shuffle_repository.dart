import '../entities/icebreaker_question.dart';

abstract class CardShuffleRepository {
  Future<IcebreakerQuestion> drawCard();
}
