class JukeboxTrack {
  final String id;
  final String youtubeUrl;
  final String videoId;
  final String title;
  final String artist;
  final String artworkUrl;
  final String addedBy;
  final String addedByName;

  const JukeboxTrack({
    required this.id,
    required this.youtubeUrl,
    required this.videoId,
    required this.title,
    required this.artist,
    required this.artworkUrl,
    required this.addedBy,
    required this.addedByName,
  });
}
