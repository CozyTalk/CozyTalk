import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/chat/domain/usecases/send_message.dart';
import '../shared_fakes.dart';

void main() {
  late FakeChatRepository repo;
  late SendMessage usecase;

  setUp(() {
    repo = FakeChatRepository();
    usecase = SendMessage(repo);
  });

  group('SendMessage', () {
    test('passes sessionId and text to repository', () async {
      await usecase(sessionId: 'room-1', text: 'hi there');
      expect(repo.sendMessageCount, 1);
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
