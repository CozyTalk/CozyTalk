import '../entities/chat_message.dart';
import '../entities/typing_user.dart';

abstract class ChatRepository {
  Stream<List<ChatMessage>> watchMessages(String sessionId);
  Stream<List<TypingUser>> watchTypingUsers(String sessionId);
  Future<void> sendMessage({required String sessionId, required String text});
  Future<void> setTyping({
    required String sessionId,
    required bool isTyping,
    required String currentUid,
    required String displayName,
    String? photoUrl,
  });
  Future<void> endSession({required String sessionId});
  Stream<Set<String>> watchPresence(String sessionId);
}
