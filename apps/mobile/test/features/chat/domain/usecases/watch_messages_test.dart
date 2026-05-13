import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/chat/domain/entities/chat_message.dart';
import 'package:mobile/features/chat/domain/usecases/watch_messages.dart';
import '../shared_fakes.dart';

void main() {
  late FakeChatRepository repo;
  late WatchMessages usecase;

  setUp(() {
    repo = FakeChatRepository();
    usecase = WatchMessages(repo);
  });

  group('WatchMessages', () {
    test('passes sessionId to repository', () {
      usecase('session-1');
      expect(repo.lastSessionId, 'session-1');
    });

    test('returns the stream from repository', () async {
      final ts = DateTime(2024, 1, 1);
      repo.messagesStream = Stream.value([
        ChatMessage(
          id: 'm1',
          senderId: 'u1',
          displayName: 'Alice',
          text: 'hello',
          timestamp: ts,
        ),
      ]);
      final result = await usecase('session-1').first;
      expect(result.length, 1);
      expect(result[0].text, 'hello');
    });
  });
}
