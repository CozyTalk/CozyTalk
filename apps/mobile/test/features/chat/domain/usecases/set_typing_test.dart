import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/chat/domain/entities/chat_message.dart';
import 'package:mobile/features/chat/domain/entities/typing_user.dart';
import 'package:mobile/features/chat/domain/repositories/chat_repository.dart';
import 'package:mobile/features/chat/domain/usecases/set_typing.dart';

class _FakeChatRepository implements ChatRepository {
  String? lastSessionId;
  bool? lastIsTyping;
  String? lastUid;
  String? lastDisplayName;

  @override
  Future<void> setTyping({
    required String sessionId,
    required bool isTyping,
    required String currentUid,
    required String displayName,
  }) async {
    lastSessionId = sessionId;
    lastIsTyping = isTyping;
    lastUid = currentUid;
    lastDisplayName = displayName;
  }

  @override
  Future<void> sendMessage({required String sessionId, required String text}) =>
      throw UnimplementedError();

  @override
  Stream<List<ChatMessage>> watchMessages(String sessionId) => throw UnimplementedError();

  @override
  Stream<List<TypingUser>> watchTypingUsers(String sessionId) => throw UnimplementedError();

  @override
  Future<void> endSession({required String sessionId}) => throw UnimplementedError();
}

void main() {
  late _FakeChatRepository repo;
  late SetTyping usecase;

  setUp(() {
    repo = _FakeChatRepository();
    usecase = SetTyping(repo);
  });

  group('SetTyping', () {
    test('passes all parameters to repository', () async {
      await usecase(
        sessionId: 'room-1',
        isTyping: true,
        currentUid: 'user-1',
        displayName: 'Alice',
      );
      expect(repo.lastSessionId, 'room-1');
      expect(repo.lastIsTyping, isTrue);
      expect(repo.lastUid, 'user-1');
      expect(repo.lastDisplayName, 'Alice');
    });

    test('passes isTyping false correctly', () async {
      await usecase(
        sessionId: 'room-1',
        isTyping: false,
        currentUid: 'user-1',
        displayName: 'Alice',
      );
      expect(repo.lastIsTyping, isFalse);
    });
  });
}
