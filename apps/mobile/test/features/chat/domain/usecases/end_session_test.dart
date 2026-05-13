import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/chat/domain/entities/chat_message.dart';
import 'package:mobile/features/chat/domain/entities/typing_user.dart';
import 'package:mobile/features/chat/domain/repositories/chat_repository.dart';
import 'package:mobile/features/chat/domain/usecases/end_session.dart';

class _FakeChatRepository implements ChatRepository {
  String? lastSessionId;
  int callCount = 0;
  Exception? error;

  @override
  Future<void> endSession({required String sessionId}) async {
    lastSessionId = sessionId;
    callCount++;
    if (error != null) throw error!;
  }

  @override
  Future<void> sendMessage({required String sessionId, required String text}) =>
      throw UnimplementedError();

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
}

void main() {
  late _FakeChatRepository repo;
  late EndSession usecase;

  setUp(() {
    repo = _FakeChatRepository();
    usecase = EndSession(repo);
  });

  group('EndSession', () {
    test('passes sessionId to repository', () async {
      await usecase('room-42');
      expect(repo.lastSessionId, 'room-42');
      expect(repo.callCount, 1);
    });

    test('propagates repository exceptions', () {
      repo.error = Exception('end failed');
      expect(() => usecase('room-42'), throwsA(isA<Exception>()));
    });
  });
}
