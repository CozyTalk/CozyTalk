import '../entities/typing_user.dart';
import '../repositories/chat_repository.dart';

class WatchTypingUsers {
  final ChatRepository _repository;
  const WatchTypingUsers(this._repository);

  Stream<List<TypingUser>> call(String sessionId) =>
      _repository.watchTypingUsers(sessionId);
}
