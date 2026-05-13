import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/chat/domain/entities/chat_message.dart';
import 'package:mobile/features/chat/domain/entities/typing_user.dart';
import 'package:mobile/features/chat/domain/repositories/chat_repository.dart';
import 'package:mobile/features/chat/domain/usecases/send_message.dart';

class _FakeChatRepository implements ChatRepository {
  String? lastSessionId;
  String? lastText;
  Exception? error;

  @override
  Future<void> sendMessage({required String sessionId, required String text}) async {
    lastSessionId = sessionId;
    lastText = text;
    if (error != null) throw error!;
  }

  @override
  Stream<List<ChatMessage>> watchMessages(String sessionId) => throw UnimplementedError();

  @override
  Stream<List<TypingUser>> watchTypingUsers(String sessionId) => throw UnimplementedError();

  @override
  Future<void> setTyping({
    required String sessionId,
    required bool isTyping,
    required String currentUid,
    required String displayName,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> endSession({required String sessionId}) => throw UnimplementedError();
}

void main() {
  late _FakeChatRepository repo;
  late SendMessage usecase;

  setUp(() {
    repo = _FakeChatRepository();
    usecase = SendMessage(repo);
  });

  group('SendMessage', () {
    test('passes sessionId and text to repository', () async {
      await usecase(sessionId: 'room-1', text: 'hi there');
      expect(repo.lastSessionId, 'room-1');
      expect(repo.lastText, 'hi there');
    });

    test('propagates repository exceptions', () {
      repo.error = Exception('send failed');
      expect(
        () => usecase(sessionId: 'room-1', text: 'hi'),
        throwsA(isA<Exception>()),
      );
    });
  });
}
