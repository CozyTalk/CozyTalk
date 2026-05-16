import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/matchmaking/domain/usecases/set_room_lock.dart';

import '../shared_fakes.dart';

void main() {
  group('SetRoomLock', () {
    late FakeMatchmakingRepository repo;
    late SetRoomLock useCase;

    setUp(() {
      repo = FakeMatchmakingRepository();
      useCase = SetRoomLock(repo);
    });

    test('calls repository with roomId and isLocked=true', () async {
      await useCase(roomId: 'LkRm3', isLocked: true);

      expect(repo.lastSetRoomLockId, 'LkRm3');
      expect(repo.lastSetRoomLockValue, true);
    });

    test('calls repository with isLocked=false to unlock', () async {
      await useCase(roomId: 'LkRm3', isLocked: false);

      expect(repo.lastSetRoomLockValue, false);
    });

    test('propagates repository exception', () async {
      repo.error = Exception('not a custom room');

      await expectLater(
        useCase(roomId: 'LkRm3', isLocked: true),
        throwsA(isA<Exception>()),
      );
    });
  });
}
