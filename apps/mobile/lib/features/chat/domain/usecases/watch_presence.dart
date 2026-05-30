import '../repositories/chat_repository.dart';

class WatchPresence {
  final ChatRepository _repository;
  const WatchPresence(this._repository);

  Stream<Set<String>> call(String sessionId) =>
      _repository.watchPresence(sessionId);
}
