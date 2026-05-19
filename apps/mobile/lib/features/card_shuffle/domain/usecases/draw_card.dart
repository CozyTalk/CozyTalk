import '../entities/icebreaker_question.dart';
import '../repositories/card_shuffle_repository.dart';

class DrawCard {
  final CardShuffleRepository _repository;
  DrawCard(this._repository);

  Future<IcebreakerQuestion> call() => _repository.drawCard();
}
