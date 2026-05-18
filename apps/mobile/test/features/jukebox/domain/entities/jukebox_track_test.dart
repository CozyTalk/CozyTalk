import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/jukebox/domain/entities/jukebox_track.dart';

void main() {
  group('JukeboxTrack', () {
    test('stores all fields', () {
      const track = JukeboxTrack(
        id: '42',
        audiomackUrl: 'https://audiomack.com/a/song/s',
        embedUrl: 'https://audiomack.com/embed/a/song/s',
        streamingUrl: 'https://cdn.example.com/a.mp3',
        streamingUrlTimeout: 1748500600,
        title: 'Test Song',
        artist: 'Test Artist',
        artworkUrl: 'https://cdn.example.com/art.jpg',
        addedBy: 'uid123',
        addedByName: 'Alice',
      );

      expect(track.id, '42');
      expect(track.audiomackUrl, 'https://audiomack.com/a/song/s');
      expect(track.embedUrl, 'https://audiomack.com/embed/a/song/s');
      expect(track.streamingUrl, 'https://cdn.example.com/a.mp3');
      expect(track.streamingUrlTimeout, 1748500600);
      expect(track.title, 'Test Song');
      expect(track.artist, 'Test Artist');
      expect(track.artworkUrl, 'https://cdn.example.com/art.jpg');
      expect(track.addedBy, 'uid123');
      expect(track.addedByName, 'Alice');
    });
  });
}
