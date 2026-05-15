import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/chat/domain/usecases/end_session.dart';
import '../shared_fakes.dart';

void main() {
  late FakeChatRepository repo;
  late EndSession usecase;

  setUp(() {
    repo = FakeChatRepository();
    usecase = EndSession(repo);
  });

  group('EndSession', () {
    test('passes sessionId to repository', () async {
      await usecase('room-42');
      expect(repo.endSessionCount, 1);
      expect(repo.lastSessionId, 'room-42');
    });

    test('propagates repository exceptions', () {
      repo.error = Exception('end failed');
      expect(() => usecase('room-42'), throwsA(isA<Exception>()));
    });
  });
}
