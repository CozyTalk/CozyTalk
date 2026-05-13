import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/chat/domain/entities/chat_message.dart';
import 'package:mobile/features/chat/domain/entities/typing_user.dart';
import 'package:mobile/features/chat/domain/repositories/chat_repository.dart';
import 'package:mobile/features/chat/domain/usecases/watch_messages.dart';

class _FakeChatRepository implements ChatRepository {
  String? lastSessionId;
  Stream<List<ChatMessage>> stream = const Stream.empty();

  @override
  Stream<List<ChatMessage>> watchMessages(String sessionId) {
    lastSessionId = sessionId;
    return stream;
  }

  @override
  Future<void> sendMessage({required String sessionId, required String text}) =>
      throw UnimplementedError();

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
  late WatchMessages usecase;

  setUp(() {
    repo = _FakeChatRepository();
    usecase = WatchMessages(repo);
  });

  group('WatchMessages', () {
    test('passes sessionId to repository', () {
      usecase('session-1');
      expect(repo.lastSessionId, 'session-1');
    });

    test('returns the stream from repository', () async {
      final ts = DateTime(2024, 1, 1);
      final messages = [
        ChatMessage(
          id: 'm1',
          senderId: 'u1',
          displayName: 'Alice',
          text: 'hello',
          timestamp: ts,
        ),
      ];
      repo.stream = Stream.value(messages);

      final result = await usecase('session-1').first;
      expect(result.length, 1);
      expect(result[0].text, 'hello');
    });
  });
}
