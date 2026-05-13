import 'package:mobile/features/chat/domain/entities/chat_message.dart';
import 'package:mobile/features/chat/domain/entities/typing_user.dart';
import 'package:mobile/features/chat/domain/repositories/chat_repository.dart';

// Shared across all chat use-case tests.
class FakeChatRepository implements ChatRepository {
  int sendMessageCount = 0;
  int endSessionCount = 0;
  int setTypingCount = 0;
  String? lastSessionId;
  String? lastText;
  bool? lastIsTyping;
  String? lastUid;
  String? lastDisplayName;
  Exception? error;

  Stream<List<ChatMessage>> messagesStream = const Stream.empty();
  Stream<List<TypingUser>> typingStream = const Stream.empty();

  @override
  Stream<List<ChatMessage>> watchMessages(String sessionId) {
    lastSessionId = sessionId;
    return messagesStream;
  }

  @override
  Stream<List<TypingUser>> watchTypingUsers(String sessionId) {
    lastSessionId = sessionId;
    return typingStream;
  }

  @override
  Future<void> sendMessage({
    required String sessionId,
    required String text,
  }) async {
    sendMessageCount++;
    lastSessionId = sessionId;
    lastText = text;
    if (error != null) throw error!;
  }

  @override
  Future<void> setTyping({
    required String sessionId,
    required bool isTyping,
    required String currentUid,
    required String displayName,
  }) async {
    setTypingCount++;
    lastSessionId = sessionId;
    lastIsTyping = isTyping;
    lastUid = currentUid;
    lastDisplayName = displayName;
  }

  @override
  Future<void> endSession({required String sessionId}) async {
    endSessionCount++;
    lastSessionId = sessionId;
    if (error != null) throw error!;
  }
}
