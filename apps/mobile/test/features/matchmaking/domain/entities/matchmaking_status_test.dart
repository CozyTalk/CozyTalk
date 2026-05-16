import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/matchmaking/domain/entities/matchmaking_status.dart';

void main() {
  group('MatchmakingStatus', () {
    test('contains all six expected values', () {
      expect(
        MatchmakingStatus.values,
        containsAll([
          MatchmakingStatus.idle,
          MatchmakingStatus.searching,
          MatchmakingStatus.waiting1v1,
          MatchmakingStatus.matched,
          MatchmakingStatus.creating,
          MatchmakingStatus.error,
        ]),
      );
      expect(MatchmakingStatus.values, hasLength(6));
    });
  });
}
