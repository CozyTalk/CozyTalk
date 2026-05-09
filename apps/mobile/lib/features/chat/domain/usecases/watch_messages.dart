import '../entities/chat_message.dart';
import '../repositories/chat_repository.dart';

class WatchMessages {
  final ChatRepository _repository;
  const WatchMessages(this._repository);

  Stream<List<ChatMessage>> call(String sessionId) =>
      _repository.watchMessages(sessionId);
}
