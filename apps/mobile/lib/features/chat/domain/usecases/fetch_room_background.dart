import '../repositories/chat_repository.dart';

class FetchRoomBackground {
  final ChatRepository _repository;
  const FetchRoomBackground(this._repository);

  Future<String?> call(String sessionId) =>
      _repository.fetchRoomBackground(sessionId);
}
