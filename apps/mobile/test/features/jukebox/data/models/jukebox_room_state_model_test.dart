import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/jukebox/data/models/jukebox_room_state_model.dart';
import 'package:mobile/features/jukebox/data/models/jukebox_track_model.dart';

void main() {
  final trackJson = {
    'id': 'dQw4w9WgXcQ',
    'youtubeUrl': 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
    'videoId': 'dQw4w9WgXcQ',
    'title': 'Song',
    'artist': 'Artist',
    'artworkUrl': 'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
    'addedBy': 'uid',
    'addedByName': 'User',
  };

  test('fromJson parses with queue', () {
    final json = {
      'isPlaying': true,
      'currentIndex': 0,
      'startedAt': 1748500000000,
      'pausedAt': 0,
      'queue': [trackJson],
    };

    final model = JukeboxRoomStateModel.fromJson(json);

    expect(model.isPlaying, isTrue);
    expect(model.currentIndex, 0);
    expect(model.startedAt, 1748500000000);
    expect(model.pausedAt, 0);
    expect(model.queue.length, 1);
    expect(model.queue.first.id, 'dQw4w9WgXcQ');
  });

  test('fromJson defaults pausedAt to 0 when absent', () {
    final json = {
      'isPlaying': false,
      'currentIndex': 0,
      'startedAt': 0,
      'queue': <Map<String, dynamic>>[],
    };

    final model = JukeboxRoomStateModel.fromJson(json);
    expect(model.pausedAt, 0);
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

  test('toEntity maps all tracks and pausedAt correctly', () {
    final model = JukeboxRoomStateModel(
      isPlaying: true,
      currentIndex: 0,
      startedAt: 123456,
      pausedAt: 5000,
      queue: [JukeboxTrackModel.fromJson(trackJson)],
    );

    final entity = model.toEntity();

    expect(entity.isPlaying, isTrue);
    expect(entity.currentIndex, 0);
    expect(entity.startedAt, 123456);
    expect(entity.pausedAt, 5000);
    expect(entity.queue.length, 1);
    expect(entity.queue.first.id, 'dQw4w9WgXcQ');
  });
}
