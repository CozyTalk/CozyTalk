import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/jukebox/domain/entities/jukebox_room_state.dart';
import 'package:mobile/features/jukebox/presentation/providers/jukebox_provider.dart';

void main() {
  group('JukeboxUiState.copyWith', () {
    const initial = JukeboxUiState(
      roomId: 'room1',
      isResolving: false,
      urlInput: 'url',
    );

    test('preserves roomState when sentinel used', () {
      final withState = initial.copyWith(
        roomState: JukeboxRoomState(
          isPlaying: true,
          currentIndex: 0,
          startedAt: 1000,
          queue: [],
        ),
      );
      final copy = withState.copyWith(isResolving: true);
      expect(copy.roomState, isNotNull);
    });

    test('clears roomState to null explicitly', () {
      final withState = initial.copyWith(
        roomState: JukeboxRoomState(
          isPlaying: false,
          currentIndex: 0,
          startedAt: 0,
          queue: [],
        ),
      );
      final cleared = withState.copyWith(roomState: null);
      expect(cleared.roomState, isNull);
    });

    test('clears resolveError to null explicitly', () {
      final withError = initial.copyWith(resolveError: 'oops');
      final cleared = withError.copyWith(resolveError: null);
      expect(cleared.resolveError, isNull);
    });

    test('preserves resolveError when sentinel used', () {
      final withError = initial.copyWith(resolveError: 'oops');
      final copy = withError.copyWith(isResolving: true);
      expect(copy.resolveError, 'oops');
    });

    test('clears roomId to null explicitly', () {
      final cleared = initial.copyWith(roomId: null);
      expect(cleared.roomId, isNull);
    });

    test('preserves roomId when sentinel used', () {
      final copy = initial.copyWith(isResolving: true);
      expect(copy.roomId, 'room1');
    });

    test('urlInput uses ?? fallback', () {
      final copy = initial.copyWith();
      expect(copy.urlInput, 'url');
    });

    test('urlInput updates when provided', () {
      final copy = initial.copyWith(urlInput: 'newurl');
      expect(copy.urlInput, 'newurl');
    });
  });
}
