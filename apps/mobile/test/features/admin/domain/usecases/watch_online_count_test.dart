import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/admin/domain/usecases/watch_online_count.dart';
import '../shared_fakes.dart';

void main() {
  late FakeAdminRepository repo;
  late WatchOnlineCount usecase;

  setUp(() {
    repo = FakeAdminRepository();
    usecase = WatchOnlineCount(repo);
  });

  group('WatchOnlineCount', () {
    test('calls repository and returns stream', () async {
      repo.returnOnlineCount = 7;
      final result = await usecase().first;
      expect(repo.watchOnlineCountCount, 1);
      expect(result, 7);
    });

    test('propagates repository error', () async {
      repo.error = Exception('network error');
      expect(usecase().first, throwsA(isA<Exception>()));
    });
  });
}
