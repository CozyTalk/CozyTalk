import '../repositories/chat_repository.dart';

class SetTyping {
  final ChatRepository _repository;
  const SetTyping(this._repository);

  Future<void> call({
    required String sessionId,
    required bool isTyping,
    required String currentUid,
    required String displayName,
<<<<<<< HEAD
=======
    String? photoUrl,
>>>>>>> 589b1f4846d9a8aa03eeae3ddffddeb67f29d43a
  }) => _repository.setTyping(
    sessionId: sessionId,
    isTyping: isTyping,
    currentUid: currentUid,
    displayName: displayName,
<<<<<<< HEAD
=======
    photoUrl: photoUrl,
>>>>>>> 589b1f4846d9a8aa03eeae3ddffddeb67f29d43a
  );
}
