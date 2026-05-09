import '../repositories/chat_repository.dart';

class SendMessage {
  final ChatRepository _repository;
  const SendMessage(this._repository);

  Future<void> call({required String sessionId, required String text}) =>
      _repository.sendMessage(sessionId: sessionId, text: text);
}
