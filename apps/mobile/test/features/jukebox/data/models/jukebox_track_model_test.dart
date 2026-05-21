import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/jukebox/data/models/jukebox_track_model.dart';

void main() {
  const json = {
    'id': 'dQw4w9WgXcQ',
    'youtubeUrl': 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
    'videoId': 'dQw4w9WgXcQ',
    'title': 'Test Song',
    'artist': 'Test Artist',
    'artworkUrl': 'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
    'addedBy': 'uid123',
    'addedByName': 'Alice',
  };

  test('fromJson parses all fields', () {
    final model = JukeboxTrackModel.fromJson(json);

    expect(model.id, 'dQw4w9WgXcQ');
    expect(model.youtubeUrl, 'https://www.youtube.com/watch?v=dQw4w9WgXcQ');
    expect(model.videoId, 'dQw4w9WgXcQ');
    expect(model.title, 'Test Song');
    expect(model.artist, 'Test Artist');
    expect(
      model.artworkUrl,
      'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
    );
    expect(model.addedBy, 'uid123');
    expect(model.addedByName, 'Alice');
  });

  test('toEntity maps all fields correctly', () {
    final model = JukeboxTrackModel.fromJson(json);
    final entity = model.toEntity();

    expect(entity.id, model.id);
    expect(entity.youtubeUrl, model.youtubeUrl);
    expect(entity.videoId, model.videoId);
    expect(entity.title, model.title);
    expect(entity.artist, model.artist);
    expect(entity.artworkUrl, model.artworkUrl);
    expect(entity.addedBy, model.addedBy);
    expect(entity.addedByName, model.addedByName);
  });
}
