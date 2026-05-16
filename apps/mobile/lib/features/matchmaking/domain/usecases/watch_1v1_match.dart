import '../repositories/matchmaking_repository.dart';

class Watch1v1Match {
  final MatchmakingRepository _repository;
  const Watch1v1Match(this._repository);

  Stream<String?> call(String uid) => _repository.watch1v1Match(uid);
}
