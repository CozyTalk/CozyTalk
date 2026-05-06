import '../repositories/chat_repository.dart';

class EndSession {
  final ChatRepository _repository;
  const EndSession(this._repository);

  Future<void> call(String sessionId) =>
      _repository.endSession(sessionId: sessionId);
}
