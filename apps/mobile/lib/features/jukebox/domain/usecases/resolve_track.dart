import '../entities/jukebox_track.dart';
import '../repositories/jukebox_repository.dart';

class ResolveTrack {
  final JukeboxRepository _repository;
  const ResolveTrack(this._repository);

  Future<JukeboxTrack> call({
    required String youtubeUrl,
    required String addedBy,
    required String addedByName,
  }) => _repository.resolveTrack(
    youtubeUrl: youtubeUrl,
    addedBy: addedBy,
    addedByName: addedByName,
  );
}
