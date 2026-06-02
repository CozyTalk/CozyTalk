import '../entities/shuffle_event.dart';
import '../repositories/chat_repository.dart';

class SetCardShuffle {
  final ChatRepository _repository;
  SetCardShuffle(this._repository);

  Future<void> call({required String sessionId, required ShuffleEvent event}) =>
      _repository.setCardShuffle(sessionId: sessionId, event: event);
}
