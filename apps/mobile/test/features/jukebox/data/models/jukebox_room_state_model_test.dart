import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/jukebox/data/models/jukebox_room_state_model.dart';
import 'package:mobile/features/jukebox/data/models/jukebox_track_model.dart';

void main() {
  final trackJson = {
    'id': '1',
    'audiomackUrl': 'https://audiomack.com/a/song/s',
    'embedUrl': 'https://audiomack.com/embed/a/song/s',
    'streamingUrl': 'https://cdn.example.com/a.mp3',
    'streamingUrlTimeout': 9999999999,
    'title': 'Song',
    'artist': 'Artist',
    'artworkUrl': 'https://cdn.example.com/art.jpg',
    'addedBy': 'uid',
    'addedByName': 'User',
  };

  test('fromJson parses with queue', () {
    final json = {
      'isPlaying': true,
      'currentIndex': 0,
      'startedAt': 1748500000000,
      'queue': [trackJson],
    };

    final model = JukeboxRoomStateModel.fromJson(json);

    expect(model.isPlaying, isTrue);
    expect(model.currentIndex, 0);
    expect(model.startedAt, 1748500000000);
    expect(model.queue.length, 1);
    expect(model.queue.first.id, '1');
  });

  test('fromJson handles empty queue', () {
    final json = {
      'isPlaying': false,
      'currentIndex': 0,
      'startedAt': 0,
      'queue': <Map<String, dynamic>>[],
    };

    final model = JukeboxRoomStateModel.fromJson(json);
    expect(model.queue, isEmpty);
  });

  test('toEntity maps all tracks correctly', () {
    final model = JukeboxRoomStateModel(
      isPlaying: true,
      currentIndex: 0,
      startedAt: 123456,
      queue: [JukeboxTrackModel.fromJson(trackJson)],
    );

    final entity = model.toEntity();

    expect(entity.isPlaying, isTrue);
    expect(entity.currentIndex, 0);
    expect(entity.startedAt, 123456);
    expect(entity.queue.length, 1);
    expect(entity.queue.first.id, '1');
  });
}
