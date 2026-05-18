import '../entities/jukebox_track.dart';
import '../repositories/jukebox_repository.dart';

class ResolveTrack {
  final JukeboxRepository _repository;
  const ResolveTrack(this._repository);

  Future<JukeboxTrack> call({
    required String audiomackUrl,
    required String addedBy,
    required String addedByName,
  }) => _repository.resolveTrack(
    audiomackUrl: audiomackUrl,
    addedBy: addedBy,
    addedByName: addedByName,
  );
}
