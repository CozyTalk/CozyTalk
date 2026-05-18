import 'package:flutter_test/flutter_test.dart';

import '../../shared_fakes.dart';

void main() {
  group('JukeboxRoomState', () {
    test('hasCurrentTrack is false when queue is empty', () {
      final state = makeRoomState();
      expect(state.hasCurrentTrack, isFalse);
      expect(state.currentTrack, isNull);
    });

    test('hasCurrentTrack is true when queue has track at currentIndex', () {
      final state = makeRoomState(queue: [makeTrack()]);
      expect(state.hasCurrentTrack, isTrue);
      expect(state.currentTrack?.id, '1');
    });

    test('hasCurrentTrack is false when currentIndex is out of bounds', () {
      final state = makeRoomState(currentIndex: 5, queue: [makeTrack()]);
      expect(state.hasCurrentTrack, isFalse);
      expect(state.currentTrack, isNull);
    });

    test('upNext returns tracks after currentIndex', () {
      final t1 = makeTrack(id: '1');
      final t2 = makeTrack(id: '2');
      final t3 = makeTrack(id: '3');
      final state = makeRoomState(currentIndex: 0, queue: [t1, t2, t3]);
      expect(state.upNext.map((t) => t.id).toList(), ['2', '3']);
    });

    test('upNext is empty when no tracks after currentIndex', () {
      final state = makeRoomState(
        currentIndex: 2,
        queue: [
          makeTrack(id: '1'),
          makeTrack(id: '2'),
          makeTrack(id: '3'),
        ],
      );
      expect(state.upNext, isEmpty);
    });

    test('upNext is empty when queue is empty', () {
      final state = makeRoomState();
      expect(state.upNext, isEmpty);
    });
  });
}
