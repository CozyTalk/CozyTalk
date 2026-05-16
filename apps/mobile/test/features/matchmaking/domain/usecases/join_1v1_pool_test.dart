import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/matchmaking/domain/usecases/join_1v1_pool.dart';

import '../shared_fakes.dart';

void main() {
  group('Join1v1Pool', () {
    late FakeMatchmakingRepository repo;
    late Join1v1Pool useCase;

    setUp(() {
      repo = FakeMatchmakingRepository();
      useCase = Join1v1Pool(repo);
    });

    test('calls repository once', () async {
      await useCase();

      expect(repo.join1v1PoolCalls, 1);
    });

    test('propagates repository exception', () async {
      repo.error = Exception('already queued');

      await expectLater(useCase(), throwsA(isA<Exception>()));
    });
  });
}
