class JukeboxTrack {
  final String id;
  final String audiomackUrl;
  final String embedUrl;
  final String streamingUrl;
  final int streamingUrlTimeout; // Unix seconds
  final String title;
  final String artist;
  final String artworkUrl;
  final String addedBy;
  final String addedByName;

  const JukeboxTrack({
    required this.id,
    required this.audiomackUrl,
    required this.embedUrl,
    required this.streamingUrl,
    required this.streamingUrlTimeout,
    required this.title,
    required this.artist,
    required this.artworkUrl,
    required this.addedBy,
    required this.addedByName,
  });
}
