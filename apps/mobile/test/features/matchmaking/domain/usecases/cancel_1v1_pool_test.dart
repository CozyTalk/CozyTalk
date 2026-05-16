import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/matchmaking/domain/usecases/cancel_1v1_pool.dart';

import '../shared_fakes.dart';

void main() {
  group('Cancel1v1Pool', () {
    late FakeMatchmakingRepository repo;
    late Cancel1v1Pool useCase;

    setUp(() {
      repo = FakeMatchmakingRepository();
      useCase = Cancel1v1Pool(repo);
    });

    test('calls repository and returns bool result', () async {
      repo.cancel1v1PoolResult = true;

      final result = await useCase();

      expect(result, true);
      expect(repo.cancel1v1PoolCalls, 1);
    });

    test('returns false when repository returns false', () async {
      repo.cancel1v1PoolResult = false;

      final result = await useCase();

      expect(result, false);
    });

    test('propagates repository exception', () async {
      repo.error = Exception('matching_in_progress');

      await expectLater(useCase(), throwsA(isA<Exception>()));
    });
  });
}
