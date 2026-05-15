import '../repositories/chat_repository.dart';

class SetTyping {
  final ChatRepository _repository;
  const SetTyping(this._repository);

  Future<void> call({
    required String sessionId,
    required bool isTyping,
    required String currentUid,
    required String displayName,
    String? photoUrl,
  }) => _repository.setTyping(
    sessionId: sessionId,
    isTyping: isTyping,
    currentUid: currentUid,
    displayName: displayName,
    photoUrl: photoUrl,
  );
}
