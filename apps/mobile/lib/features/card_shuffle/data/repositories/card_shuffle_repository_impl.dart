import '../../domain/entities/icebreaker_question.dart';
import '../../domain/repositories/card_shuffle_repository.dart';
import '../datasources/card_shuffle_datasource.dart';

class CardShuffleRepositoryImpl implements CardShuffleRepository {
  final CardShuffleDatasource _datasource;
  CardShuffleRepositoryImpl(this._datasource);

  @override
  Future<IcebreakerQuestion> drawCard() => _datasource.drawCard();
}
