import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/word_filter/data/datasources/word_filter_datasource.dart';
import 'package:mobile/features/word_filter/data/repositories/word_filter_repository_impl.dart';

class _FakeDatasource implements WordFilterDatasource {
  _FakeDatasource({this.returnValue = '', this.shouldThrow = false});

  final String returnValue;
  final bool shouldThrow;

  int censorCallCount = 0;
  String? lastArg;

  @override
  Future<String> censorText(String text) async {
    censorCallCount++;
    lastArg = text;
    if (shouldThrow) throw Exception('datasource error');
    return returnValue;
  }

  @override
  Future<void> seedIfNeeded() async {}
}

void main() {
  late _FakeDatasource fake;
  late WordFilterRepositoryImpl repo;

  setUp(() {
    fake = _FakeDatasource(returnValue: '***');
    repo = WordFilterRepositoryImpl(fake);
  });

  group('WordFilterRepositoryImpl', () {
    test('delegates censorText to datasource and returns result', () async {
      final result = await repo.censorText('badword');
      expect(result, '***');
      expect(fake.censorCallCount, 1);
      expect(fake.lastArg, 'badword');
    });

    test('propagates datasource exception', () async {
      final throwing = _FakeDatasource(shouldThrow: true);
      final r = WordFilterRepositoryImpl(throwing);
      expect(() async => r.censorText('text'), throwsA(isA<Exception>()));
    });
  });
}
