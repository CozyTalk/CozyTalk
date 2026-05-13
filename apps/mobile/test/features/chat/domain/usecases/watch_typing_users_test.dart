import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/chat/domain/entities/typing_user.dart';
import 'package:mobile/features/chat/domain/usecases/watch_partner_typing.dart';
import '../shared_fakes.dart';

void main() {
  late FakeChatRepository repo;
  late WatchTypingUsers usecase;

  setUp(() {
    repo = FakeChatRepository();
    usecase = WatchTypingUsers(repo);
  });

  group('WatchTypingUsers', () {
    test('passes sessionId to repository', () {
      usecase('session-1');
      expect(repo.lastSessionId, 'session-1');
    });

    test('returns typing users from repository stream', () async {
      repo.typingStream = Stream.value([
        const TypingUser(uid: 'u1', displayName: 'Alice'),
        const TypingUser(uid: 'u2', displayName: 'Bob'),
      ]);
      final result = await usecase('session-1').first;
      expect(result.length, 2);
      expect(result[0].uid, 'u1');
      expect(result[1].displayName, 'Bob');
    });
  });
}
