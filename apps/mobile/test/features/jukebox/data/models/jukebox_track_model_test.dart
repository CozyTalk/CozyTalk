import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/jukebox/data/models/jukebox_track_model.dart';

void main() {
  const json = {
    'id': '42',
    'audiomackUrl': 'https://audiomack.com/a/song/s',
    'embedUrl': 'https://audiomack.com/embed/a/song/s',
    'streamingUrl': 'https://cdn.example.com/a.mp3',
    'streamingUrlTimeout': 1748500600,
    'title': 'Test Song',
    'artist': 'Test Artist',
    'artworkUrl': 'https://cdn.example.com/art.jpg',
    'addedBy': 'uid123',
    'addedByName': 'Alice',
  };

  test('fromJson parses all fields', () {
    final model = JukeboxTrackModel.fromJson(json);

    expect(model.id, '42');
    expect(model.audiomackUrl, 'https://audiomack.com/a/song/s');
    expect(model.embedUrl, 'https://audiomack.com/embed/a/song/s');
    expect(model.streamingUrl, 'https://cdn.example.com/a.mp3');
    expect(model.streamingUrlTimeout, 1748500600);
    expect(model.title, 'Test Song');
    expect(model.artist, 'Test Artist');
    expect(model.artworkUrl, 'https://cdn.example.com/art.jpg');
    expect(model.addedBy, 'uid123');
    expect(model.addedByName, 'Alice');
  });

  test('toEntity maps all fields correctly', () {
    final model = JukeboxTrackModel.fromJson(json);
    final entity = model.toEntity();

    expect(entity.id, model.id);
    expect(entity.audiomackUrl, model.audiomackUrl);
    expect(entity.embedUrl, model.embedUrl);
    expect(entity.streamingUrl, model.streamingUrl);
    expect(entity.streamingUrlTimeout, model.streamingUrlTimeout);
    expect(entity.title, model.title);
    expect(entity.artist, model.artist);
    expect(entity.artworkUrl, model.artworkUrl);
    expect(entity.addedBy, model.addedBy);
    expect(entity.addedByName, model.addedByName);
  });
}
