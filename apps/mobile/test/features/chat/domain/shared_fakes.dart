import 'package:mobile/features/chat/domain/entities/chat_message.dart';
import 'package:mobile/features/chat/domain/entities/shuffle_event.dart';
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
  String? lastPhotoUrl;
  Exception? error;

  Stream<List<ChatMessage>> messagesStream = const Stream.empty();
  Stream<List<TypingUser>> typingStream = const Stream.empty();
  Stream<Set<String>> presenceStream = const Stream.empty();
  Stream<ShuffleEvent?> shuffleStream = const Stream.empty();

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
  Stream<Set<String>> watchPresence(String sessionId) {
    lastSessionId = sessionId;
    return presenceStream;
  }

  @override
  Stream<ShuffleEvent?> watchCardShuffle(String sessionId) {
    lastSessionId = sessionId;
    return shuffleStream;
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
    String? photoUrl,
  }) async {
    setTypingCount++;
    lastSessionId = sessionId;
    lastIsTyping = isTyping;
    lastUid = currentUid;
    lastDisplayName = displayName;
    lastPhotoUrl = photoUrl;
  }

  @override
  Future<String?> fetchRoomBackground(String sessionId) async => null;

  @override
  Future<void> setCardShuffle({
    required String sessionId,
    required ShuffleEvent event,
  }) async {}

  @override
  Future<void> endSession({required String sessionId}) async {
    endSessionCount++;
    lastSessionId = sessionId;
    if (error != null) throw error!;
  }
}
