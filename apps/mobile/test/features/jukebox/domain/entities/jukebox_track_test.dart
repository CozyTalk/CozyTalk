import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/jukebox/domain/entities/jukebox_track.dart';

void main() {
  group('JukeboxTrack', () {
    test('stores all fields', () {
      const track = JukeboxTrack(
        id: 'dQw4w9WgXcQ',
        youtubeUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        videoId: 'dQw4w9WgXcQ',
        title: 'Test Song',
        artist: 'Test Artist',
        artworkUrl: 'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
        addedBy: 'uid123',
        addedByName: 'Alice',
      );

      expect(track.id, 'dQw4w9WgXcQ');
      expect(track.youtubeUrl, 'https://www.youtube.com/watch?v=dQw4w9WgXcQ');
      expect(track.videoId, 'dQw4w9WgXcQ');
      expect(track.title, 'Test Song');
      expect(track.artist, 'Test Artist');
      expect(
        track.artworkUrl,
        'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
      );
      expect(track.addedBy, 'uid123');
      expect(track.addedByName, 'Alice');
    });
  });
}
