import '../entities/chat_message.dart';
import '../entities/shuffle_event.dart';
import '../entities/typing_user.dart';

abstract class ChatRepository {
  Stream<List<ChatMessage>> watchMessages(String sessionId);
  Stream<List<TypingUser>> watchTypingUsers(String sessionId);
  Stream<Set<String>> watchPresence(String sessionId);
  Stream<ShuffleEvent?> watchCardShuffle(String sessionId);
  Future<String?> fetchRoomBackground(String sessionId);
  Future<void> sendMessage({required String sessionId, required String text});
  Future<void> setTyping({
    required String sessionId,
    required bool isTyping,
    required String currentUid,
    required String displayName,
    String? photoUrl,
  });
  Future<void> setCardShuffle({
    required String sessionId,
    required ShuffleEvent event,
  });
  Future<void> endSession({required String sessionId});
}
