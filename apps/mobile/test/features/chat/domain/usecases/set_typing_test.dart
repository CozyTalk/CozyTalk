import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/chat/domain/usecases/set_typing.dart';
import '../shared_fakes.dart';

void main() {
  late FakeChatRepository repo;
  late SetTyping usecase;

  setUp(() {
    repo = FakeChatRepository();
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
      expect(repo.setTypingCount, 1);
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

    test('passes optional photoUrl to repository', () async {
      await usecase(
        sessionId: 'room-1',
        isTyping: true,
        currentUid: 'user-1',
        displayName: 'Alice',
        photoUrl: 'https://example.com/alice.jpg',
      );
      expect(repo.lastPhotoUrl, 'https://example.com/alice.jpg');
    });

    test('photoUrl defaults to null when omitted', () async {
      await usecase(
        sessionId: 'room-1',
        isTyping: true,
        currentUid: 'user-1',
        displayName: 'Alice',
      );
      expect(repo.lastPhotoUrl, isNull);
    });
  });
}
