import 'jukebox_track.dart';

class JukeboxRoomState {
  final bool isPlaying;
  final int currentIndex;
  final int startedAt; // ms epoch: virtual t=0 for this track
  final int pausedAt; // ms into the track when paused; 0 while playing
  final List<JukeboxTrack> queue;

  const JukeboxRoomState({
    required this.isPlaying,
    required this.currentIndex,
    required this.startedAt,
    this.pausedAt = 0,
    required this.queue,
  });

  bool get hasCurrentTrack => queue.isNotEmpty && currentIndex < queue.length;

  JukeboxTrack? get currentTrack =>
      hasCurrentTrack ? queue[currentIndex] : null;

  List<JukeboxTrack> get upNext => queue.length > currentIndex + 1
      ? queue.sublist(currentIndex + 1)
      : const [];
}
