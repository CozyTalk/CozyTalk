import '../../domain/repositories/word_filter_repository.dart';
import '../datasources/word_filter_datasource.dart';

class WordFilterRepositoryImpl implements WordFilterRepository {
  const WordFilterRepositoryImpl(this._datasource);

  final WordFilterDatasource _datasource;

  @override
  Future<String> censorText(String text) => _datasource.censorText(text);
}
