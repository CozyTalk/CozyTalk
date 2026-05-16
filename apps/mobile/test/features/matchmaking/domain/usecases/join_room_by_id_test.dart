import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/matchmaking/domain/entities/room.dart';
import 'package:mobile/features/matchmaking/domain/usecases/join_room_by_id.dart';

import '../shared_fakes.dart';

void main() {
  group('JoinRoomById', () {
    late FakeMatchmakingRepository repo;
    late JoinRoomById useCase;

    setUp(() {
      repo = FakeMatchmakingRepository();
      useCase = JoinRoomById(repo);
    });

    test('passes roomId to repository and returns result', () async {
      repo.joinRoomByIdResult = (
        roomId: 'JnRm5',
        mode: RoomMode.group,
        roomType: RoomType.custom,
      );

      final result = await useCase('JnRm5');

      expect(result.roomId, 'JnRm5');
      expect(result.mode, RoomMode.group);
      expect(result.roomType, RoomType.custom);
      expect(repo.lastJoinRoomByIdArg, 'JnRm5');
    });

    test('propagates repository exception', () async {
      repo.error = Exception('room locked');

      await expectLater(useCase('XyZAb'), throwsA(isA<Exception>()));
    });
  });
}
