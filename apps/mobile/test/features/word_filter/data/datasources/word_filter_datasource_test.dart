import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/word_filter/data/datasources/word_filter_database_helper.dart';
import 'package:mobile/features/word_filter/data/datasources/word_filter_datasource.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeDbHelper extends WordFilterDatabaseHelper {
  _FakeDbHelper({required this.enWords, required this.thWords});

  final List<String> enWords;
  final List<String> thWords;

  @override
  Future<List<Map<String, dynamic>>> getWordsByLanguage(String language) async {
    if (language == 'en') return enWords.map((w) => {'word': w}).toList();
    if (language == 'th') return thWords.map((w) => {'word': w}).toList();
    return [];
  }
}

Future<WordFilterDatasourceImpl> _makeDatasource({
  List<String> enWords = const ['fuck', 'shit'],
  List<String> thWords = const ['หี', 'ควย'],
  bool enabled = true,
}) async {
  SharedPreferences.setMockInitialValues({'db_seeded_v1': true});
  final prefs = await SharedPreferences.getInstance();
  return WordFilterDatasourceImpl(
    _FakeDbHelper(enWords: enWords, thWords: thWords),
    () => enabled,
    prefs,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WordFilterDatasourceImpl.censorText', () {
    test('returns original text when flag is disabled', () async {
      final ds = await _makeDatasource(enabled: false);
      expect(await ds.censorText('fuck'), 'fuck');
    });

    test('censors exact EN banned word', () async {
      final ds = await _makeDatasource();
      expect(await ds.censorText('fuck'), '****');
    });

    test('censors EN word surrounded by clean words', () async {
      final ds = await _makeDatasource();
      expect(await ds.censorText('hello fuck world'), 'hello **** world');
    });

    test('censors EN word regardless of case', () async {
      final ds = await _makeDatasource();
      expect(await ds.censorText('FUCK'), '****');
      expect(await ds.censorText('Fuck'), '****');
    });

    test('censors EN word with trailing punctuation', () async {
      final ds = await _makeDatasource();
      expect(await ds.censorText('fuck!'), '*****');
      expect(await ds.censorText('fuck,'), '*****');
    });

    test('censors EN word with surrounding punctuation', () async {
      final ds = await _makeDatasource();
      expect(await ds.censorText('(fuck)'), '******');
    });

    test('censors multiple EN banned words in one message', () async {
      final ds = await _makeDatasource();
      expect(await ds.censorText('fuck this shit'), '**** this ****');
    });

    test('does not censor clean EN words', () async {
      final ds = await _makeDatasource();
      expect(await ds.censorText('hello world'), 'hello world');
    });

    test('censors Thai banned word via full-text scan', () async {
      final ds = await _makeDatasource();
      expect(await ds.censorText('ประโยค หี ทดสอบ'), 'ประโยค ** ทดสอบ');
    });

    test('censors Thai word embedded in text without spaces', () async {
      final ds = await _makeDatasource();
      final result = await ds.censorText('คำหยาบหีนี่');
      expect(result, isNot(contains('หี')));
    });

    test('empty string is returned unchanged', () async {
      final ds = await _makeDatasource();
      expect(await ds.censorText(''), '');
    });

    test('resets initFuture and retries after load failure', () async {
      SharedPreferences.setMockInitialValues({'db_seeded_v1': true});
      final prefs = await SharedPreferences.getInstance();

      final failHelper = _FailOnFirstCallDbHelper();
      final ds = WordFilterDatasourceImpl(failHelper, () => true, prefs);

      // First call fails because the helper throws on its first invocation
      await expectLater(ds.censorText('test'), throwsA(anything));

      // Second call succeeds — initFuture was reset after the failure
      expect(await ds.censorText('test'), 'test');
    });
  });
}

class _FailOnFirstCallDbHelper extends WordFilterDatabaseHelper {
  bool _hasFailed = false;

  @override
  Future<List<Map<String, dynamic>>> getWordsByLanguage(String language) async {
    if (!_hasFailed) {
      _hasFailed = true;
      throw Exception('simulated DB failure');
    }
    return [];
  }
}
