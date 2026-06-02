import '../entities/shuffle_event.dart';
import '../repositories/chat_repository.dart';

class WatchCardShuffle {
  final ChatRepository _repository;
  WatchCardShuffle(this._repository);

  Stream<ShuffleEvent?> call(String sessionId) =>
      _repository.watchCardShuffle(sessionId);
}
