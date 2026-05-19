import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/admin/domain/usecases/get_chat_log_url.dart';
import '../shared_fakes.dart';

void main() {
  late FakeAdminRepository repo;
  late GetChatLogUrl usecase;

  setUp(() {
    repo = FakeAdminRepository();
    usecase = GetChatLogUrl(repo);
  });

  group('GetChatLogUrl', () {
    test('calls repository and returns url', () async {
      repo.returnChatLogUrl = 'https://storage.example.com/signed/chat_log';
      final url = await usecase('r1');
      expect(repo.getChatLogUrlCount, 1);
      expect(repo.lastReportId, 'r1');
      expect(url, 'https://storage.example.com/signed/chat_log');
    });

    test('propagates repository exception', () {
      repo.error = Exception('no chat log');
      expect(() => usecase('r1'), throwsA(isA<Exception>()));
    });
  });
}
