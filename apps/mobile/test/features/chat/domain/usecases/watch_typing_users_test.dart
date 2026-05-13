import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/chat/domain/entities/chat_message.dart';
import 'package:mobile/features/chat/domain/entities/typing_user.dart';
import 'package:mobile/features/chat/domain/repositories/chat_repository.dart';
import 'package:mobile/features/chat/domain/usecases/watch_partner_typing.dart';

class _FakeChatRepository implements ChatRepository {
  String? lastSessionId;
  Stream<List<TypingUser>> stream = const Stream.empty();

  @override
  Stream<List<TypingUser>> watchTypingUsers(String sessionId) {
    lastSessionId = sessionId;
    return stream;
  }

  @override
  Future<void> sendMessage({required String sessionId, required String text}) =>
      throw UnimplementedError();

  @override
  Stream<List<ChatMessage>> watchMessages(String sessionId) => throw UnimplementedError();

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
  late WatchTypingUsers usecase;

  setUp(() {
    repo = _FakeChatRepository();
    usecase = WatchTypingUsers(repo);
  });

  group('WatchTypingUsers', () {
    test('passes sessionId to repository', () {
      usecase('session-1');
      expect(repo.lastSessionId, 'session-1');
    });

    test('returns typing users from repository stream', () async {
      final users = [
        const TypingUser(uid: 'u1', displayName: 'Alice'),
        const TypingUser(uid: 'u2', displayName: 'Bob'),
      ];
      repo.stream = Stream.value(users);

      final result = await usecase('session-1').first;
      expect(result.length, 2);
      expect(result[0].uid, 'u1');
      expect(result[1].displayName, 'Bob');
    });
  });
}
