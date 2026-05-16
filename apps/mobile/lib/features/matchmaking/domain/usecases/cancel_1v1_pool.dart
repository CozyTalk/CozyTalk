import '../repositories/matchmaking_repository.dart';

class Cancel1v1Pool {
  final MatchmakingRepository _repository;
  const Cancel1v1Pool(this._repository);

  Future<bool> call() => _repository.cancel1v1Pool();
}
