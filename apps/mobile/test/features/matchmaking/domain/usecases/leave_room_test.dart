import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/matchmaking/domain/usecases/leave_room.dart';

import '../shared_fakes.dart';

void main() {
  group('LeaveRoom', () {
    late FakeMatchmakingRepository repo;
    late LeaveRoom useCase;

    setUp(() {
      repo = FakeMatchmakingRepository();
      useCase = LeaveRoom(repo);
    });

    test('calls repository with correct roomId', () async {
      await useCase('LvRm9');

      expect(repo.lastLeaveRoomIdArg, 'LvRm9');
    });

    test('propagates repository exception', () async {
      repo.error = Exception('not a member');

      await expectLater(useCase('LvRm9'), throwsA(isA<Exception>()));
    });
  });
}
