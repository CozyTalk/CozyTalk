import '../repositories/word_filter_repository.dart';

class CensorText {
  const CensorText(this._repository);

  final WordFilterRepository _repository;

  Future<String> call(String text) => _repository.censorText(text);
}
