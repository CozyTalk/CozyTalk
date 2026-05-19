import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/icebreaker_question.dart';
import '../../domain/usecases/draw_card.dart';
import '../../data/datasources/card_shuffle_datasource.dart';
import '../../data/repositories/card_shuffle_repository_impl.dart';

class CardShuffleState {
  final IcebreakerQuestion? currentQuestion;
  final bool isLoading;
  final String? error;

  const CardShuffleState({
    this.currentQuestion,
    this.isLoading = false,
    this.error,
  });

  CardShuffleState copyWith({
    Object? currentQuestion = _sentinel,
    bool? isLoading,
    Object? error = _sentinel,
  }) {
    return CardShuffleState(
      currentQuestion: currentQuestion == _sentinel
          ? this.currentQuestion
          : currentQuestion as IcebreakerQuestion?,
      isLoading: isLoading ?? this.isLoading,
      error: error == _sentinel ? this.error : error as String?,
    );
  }
}

const _sentinel = Object();

final _cardShuffleDatasourceProvider = Provider<CardShuffleDatasource>(
  (ref) => CardShuffleDatasourceImpl(),
);

final _cardShuffleRepositoryProvider = Provider(
  (ref) => CardShuffleRepositoryImpl(ref.watch(_cardShuffleDatasourceProvider)),
);

final _drawCardProvider = Provider(
  (ref) => DrawCard(ref.watch(_cardShuffleRepositoryProvider)),
);

final cardShuffleNotifierProvider =
    NotifierProvider<CardShuffleNotifier, CardShuffleState>(
      CardShuffleNotifier.new,
    );

class CardShuffleNotifier extends Notifier<CardShuffleState> {
  @override
  CardShuffleState build() => const CardShuffleState();

  Future<IcebreakerQuestion?> draw() async {
    if (state.isLoading) return null;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final question = await ref.read(_drawCardProvider).call();
      state = state.copyWith(currentQuestion: question, isLoading: false);
      return question;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to draw card');
      return null;
    }
  }
}
