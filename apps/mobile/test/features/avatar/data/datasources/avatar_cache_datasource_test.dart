import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/avatar/data/datasources/avatar_cache_datasource.dart';
import 'package:mobile/features/avatar/data/models/avatar_decoration_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _model = AvatarDecorationModel(hatKey: 'Crown', moodKey: 'Happy');

void main() {
  late AvatarCacheDatasourceImpl cache;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    cache = AvatarCacheDatasourceImpl(prefs);
  });

  group('AvatarCacheDatasource', () {
    test('read returns null when key missing', () async {
      final result = await cache.read('uid-1');
      expect(result, isNull);
    });

    test('write then read returns correct model', () async {
      await cache.write('uid-1', _model);
      final result = await cache.read('uid-1');
      expect(result?.hatKey, 'Crown');
      expect(result?.moodKey, 'Happy');
    });

    test('write then clear makes read return null', () async {
      await cache.write('uid-1', _model);
      await cache.clear('uid-1');
      final result = await cache.read('uid-1');
      expect(result, isNull);
    });

    test('uid isolation: write uid-A, read uid-B returns null', () async {
      await cache.write('uid-A', _model);
      final result = await cache.read('uid-B');
      expect(result, isNull);
    });

    test('read handles malformed JSON without throwing', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('avatar_cache_uid-1', 'not-valid-json');
      final result = await cache.read('uid-1');
      expect(result, isNull);
    });
  });
}
