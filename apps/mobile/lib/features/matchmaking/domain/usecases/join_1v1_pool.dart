import '../repositories/matchmaking_repository.dart';

class Join1v1Pool {
  final MatchmakingRepository _repository;
  const Join1v1Pool(this._repository);

  Future<void> call({
    String? interestText,
    String? backgroundTheme,
    List<String> excludeUids = const [],
  }) =>
      _repository.join1v1Pool(
        interestText: interestText,
        backgroundTheme: backgroundTheme,
        excludeUids: excludeUids,
      );
}
