import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/admin/domain/usecases/watch_pending_count.dart';
import '../shared_fakes.dart';

void main() {
  late FakeAdminRepository repo;
  late WatchPendingCount usecase;

  setUp(() {
    repo = FakeAdminRepository();
    usecase = WatchPendingCount(repo);
  });

  group('WatchPendingCount', () {
    test('calls repository and returns stream', () async {
      repo.returnPendingCount = 7;
      final result = await usecase().first;
      expect(repo.watchPendingCountCount, 1);
      expect(result, 7);
    });

    test('propagates repository error', () async {
      repo.error = Exception('network error');
      expect(usecase().first, throwsA(isA<Exception>()));
    });
  });
}
