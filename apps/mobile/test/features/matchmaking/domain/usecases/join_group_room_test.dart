import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/matchmaking/domain/usecases/join_group_room.dart';

import '../shared_fakes.dart';

void main() {
  group('JoinGroupRoom', () {
    late FakeMatchmakingRepository repo;
    late JoinGroupRoom useCase;

    setUp(() {
      repo = FakeMatchmakingRepository();
      useCase = JoinGroupRoom(repo);
    });

    test('delegates to repository and returns result', () async {
      repo.joinGroupRoomResult = (roomId: 'Tt3Xy', isNewRoom: true);

      final result = await useCase();

      expect(result.roomId, 'Tt3Xy');
      expect(result.isNewRoom, true);
      expect(repo.joinGroupRoomCalls, 1);
    });

    test('propagates repository exception', () async {
      repo.error = Exception('network error');

      await expectLater(useCase(), throwsA(isA<Exception>()));
    });
  });
}
