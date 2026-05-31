import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/matchmaking/presentation/providers/matchmaking_provider.dart';

void main() {
  group('MatchmakingState.partnerUids', () {
    test('defaults to empty list in initial state', () {
      const state = MatchmakingState();
      expect(state.partnerUids, isEmpty);
    });

    test('copyWith sets partnerUids', () {
      const state = MatchmakingState();
      final updated = state.copyWith(partnerUids: ['uid-a', 'uid-b']);
      expect(updated.partnerUids, ['uid-a', 'uid-b']);
    });

    test('copyWith without partnerUids preserves existing value', () {
      const state = MatchmakingState();
      final withUids = state.copyWith(partnerUids: ['uid-a']);
      final preserved = withUids.copyWith(roomId: 'r1');
      expect(preserved.partnerUids, ['uid-a']);
    });

    test('copyWith with empty list clears partnerUids', () {
      const state = MatchmakingState();
      final withUids = state.copyWith(partnerUids: ['uid-a']);
      final cleared = withUids.copyWith(partnerUids: []);
      expect(cleared.partnerUids, isEmpty);
    });

    test('other fields are unaffected when only partnerUids changes', () {
      const state = MatchmakingState(roomId: 'room-1');
      final updated = state.copyWith(partnerUids: ['uid-x']);
      expect(updated.roomId, 'room-1');
    });
  });
}
